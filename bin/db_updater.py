# -*- coding: utf-8 -*-
import subprocess
import psycopg2
import sys
import os
import re
import importlib
from py_cerebro import cclib
from xml.dom.minidom import parseString

if len(sys.argv) != 2:
  print('Syntax is: db_updater.py <db-name-to-update>');
  sys.exit(1);

DB_NAME = sys.argv[1];
BIN_DIR = os.path.realpath(__file__).replace('\\', '/').rsplit('/', 1)[0];
DB_DIR = os.path.realpath(BIN_DIR + '/../' + DB_NAME).replace('\\', '/')
DB_STATE_TABLE = 'update_log';
DB_INIT_SQL = 'dbup_init.sql';
#DB_STATE_COLUMN='db_version';

if not os.path.exists(DB_DIR):
  print('DB directory to update does not exist:', DB_DIR);
  sys.exit(2);

CONF_FILE = BIN_DIR + '/../' + DB_NAME + '.py';
if not os.path.isfile(CONF_FILE):
  print('Config file "' + CONF_FILE + '" does not exist');
  sys.exit(2);

sys.path.append(BIN_DIR + '/../')
conf = importlib.import_module(DB_NAME)

# print('DB_USER', conf.DB_USER)

PG_URL = "user={0} password={1} host={2} port={3} dbname={4} ".format(conf.DB_USER, conf.DB_PSWD, conf.DB_HOST, conf.DB_PORT,  conf.DB_SCHEMA);
dbcon = psycopg2.connect(PG_URL);
dbcon.set_isolation_level(psycopg2.extensions.ISOLATION_LEVEL_AUTOCOMMIT)
db = dbcon.cursor()

# ------------------------- #
def dbApiVersion():
  db.execute("SELECT count(1) FROM information_schema.columns WHERE table_schema='public' AND table_name='{0}'".format(DB_STATE_TABLE)); #  and column_name='{1} DB_STATE_COLUMN
  apiVersion = db.fetchone()[0];
  if apiVersion != 0:
    db.execute("SELECT revision FROM {0} WHERE script_name='' ORDER BY mtm DESC LIMIT 1".format(DB_STATE_TABLE));
    apiVersion = db.fetchone()[0];

  return apiVersion;

def sqlLogEntry(sqlPath, revision):
  return "\n;" + "INSERT into {0}(revision, script_name) values ({2}, '{1}')".format(DB_STATE_TABLE, sqlPath, revision)

# ------------------------- #
def dbInit():
  initFileName = BIN_DIR + '/' + DB_INIT_SQL;
  with open(initFileName, 'rb') as fInitScript:
    sql = fInitScript.read().decode('utf_8_sig');

  sql += sqlLogEntry('', 1);

  #print(sql);
  db.execute(sql);

# ------------------------- #
def dbUpdate(sqlPath, revision):
  filePath = DB_DIR + sqlPath;

  if not os.path.isfile(filePath):
    print(filePath, ': skip (no file):');
    return;

  checkSql = "select count(1) from {0} where revision={1} and script_name='{2}'".format(DB_STATE_TABLE, revision, sqlPath)
  db.execute(checkSql);
  scriptUptodate = db.fetchone()[0];

  if scriptUptodate:
    print(sqlPath, ': skip (done at rev. {0})'.format(revision));
    return;
  else:
    isSchema = '.!.' in sqlPath;
    if isSchema:
      checkSql = "select count(1) from {0} where script_name='{1}'".format(DB_STATE_TABLE, sqlPath)
      db.execute(checkSql);
      anyUpateBefore = db.fetchone()[0];
      if anyUpateBefore != 0:
        print(sqlPath, ': WARING: Schema file MODIFIED after inserted in DB! You have to check diffs manually!');
        return;

  # print(sqlPath, ': updating');
  with open(filePath, 'rb') as f:
    sql = f.read().decode('utf_8_sig');

  sql += sqlLogEntry(sqlPath, revision);

  #print(sql);
  try:
    db.execute(sql);
    print(sqlPath, ': updated! (at rev. {0})'.format(revision));
  except Exception as ex:
    print('FAILED! : ', str(ex));
    print("Problem in " + sqlPath);
    sys.exit(2);




# ------------------------- #
def svnUpdateRepo():
  #print('Update DB source in ' + DB_DIR + '...');
  upResult = cclib.shell('svn up "{0}"'.format(DB_DIR))
  #print('upResult:', upResult);
  revision_search = re.search('At revision ([0-9].*)\.', upResult, re.MULTILINE);
  if not revision_search:
    revision_search = re.search('Updated to revision ([0-9].*)\.', upResult, re.MULTILINE);

  #print('revision_search', revision_search);
  if not revision_search:
    print('Revision number missed');
    sys.exit(2);

  revision = int(revision_search.group(1))
  return revision;


# ------------------------- #
def svnUpdatedList(fromVersion):
  repoPrefix = cclib.shell('svn info --show-item relative-url "{0}"'.format(DB_DIR)).strip()
  if not repoPrefix.startswith('^'):
    print('Strange repo relative path', repoPrefix);
    sys.exit(2);
  repoPrefix = repoPrefix[1:];
  # print('repoPrefix:', repoPrefix);

  logResult = cclib.shell('svn --xml -v -r {1}:HEAD log "{0}"'.format(DB_DIR, fromVersion))
  # print('logResult:', logResult);

  upFiles = dict();
  dom = parseString(logResult);
  revisions = dom.getElementsByTagName("logentry");

  for rev in revisions:
    revNo = int(rev.getAttribute('revision'));
    date = rev.getElementsByTagName("date")[0];
    msg = rev.getElementsByTagName("msg")[0];
    # print('revNo:', revNo, date.childNodes[0].nodeValue);

    paths = rev.getElementsByTagName("path");
    # print('paths len:', paths.length);
    for path in paths:
      pname = path.childNodes[0].nodeValue;
      # print('... ', pname);
      if pname.startswith(repoPrefix) and pname.endswith('.sql'):
        sname = pname[len(repoPrefix):]
        upFiles[sname] = upFiles[sname] if (sname in upFiles and upFiles[sname] > revNo) else revNo;

  return upFiles;

# ------------------------- #
dbVersion = dbApiVersion(); #dbVersion = 0;
if dbVersion == 0:
  print('Init DB update facility...');
  dbInit();
  print('... OK');
  dbVersion = dbApiVersion();

repoRevision = svnUpdateRepo();
if repoRevision == dbVersion:
  print('{0} is up to date'.format(DB_NAME));
  sys.exit(0)

scriptsToUpdate = svnUpdatedList(dbVersion);
# print('scriptsToUpdate', scriptsToUpdate)
scriptsOrder = sorted(scriptsToUpdate.keys());

if len(scriptsOrder):
  print('updating Database: {0} rev. {1} -> {2}'.format(DB_NAME, dbVersion, repoRevision));
else:
  print('no changes to update for ', DB_NAME);

for path in scriptsOrder:
  dbUpdate(path, scriptsToUpdate[path]);

db.execute(sqlLogEntry('', repoRevision));
