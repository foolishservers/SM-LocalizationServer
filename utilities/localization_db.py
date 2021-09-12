import vdf
import sqlite3
import codecs
import os

# Prereq:
# pip install vdf

GAME_DIR = 'C:/Program Files (x86)/Steam/steamapps/common/Team Fortress 2/tf/'
LANGUAGE_DB = GAME_DIR + 'language-db.sq3'

LANGUAGE_FILES = [
    GAME_DIR + 'resource/tf_brazilian.txt',
    GAME_DIR + 'resource/tf_bulgarian.txt',
    GAME_DIR + 'resource/tf_czech.txt',
    GAME_DIR + 'resource/tf_danish.txt',
    GAME_DIR + 'resource/tf_dutch.txt',
    GAME_DIR + 'resource/tf_english.txt',
    GAME_DIR + 'resource/tf_finnish.txt',
    GAME_DIR + 'resource/tf_french.txt',
    GAME_DIR + 'resource/tf_german.txt',
    GAME_DIR + 'resource/tf_greek.txt',
    GAME_DIR + 'resource/tf_hungarian.txt',
    GAME_DIR + 'resource/tf_italian.txt',
    GAME_DIR + 'resource/tf_japanese.txt',
    GAME_DIR + 'resource/tf_korean.txt',
    GAME_DIR + 'resource/tf_norwegian.txt',
    GAME_DIR + 'resource/tf_polish.txt',
    GAME_DIR + 'resource/tf_portuguese.txt',
    GAME_DIR + 'resource/tf_romanian.txt',
    GAME_DIR + 'resource/tf_russian.txt',
    GAME_DIR + 'resource/tf_schinese.txt',
    GAME_DIR + 'resource/tf_spanish.txt',
    GAME_DIR + 'resource/tf_swedish.txt',
    GAME_DIR + 'resource/tf_tchinese.txt',
    GAME_DIR + 'resource/tf_thai.txt',
    GAME_DIR + 'resource/tf_turkish.txt',
    GAME_DIR + 'resource/tf_ukrainian.txt'
]

LANGUAGE_FILES_KOREANA = [
    GAME_DIR + 'resource/tf_koreana.txt'
]

# Some of the tokens used in other language refer to the English-language version.
# Dropped them for deduplication.
DROP_LOCALIZED_ENGLISH_TOKEN = True

db = sqlite3.connect(LANGUAGE_DB)
dbc = db.cursor()

dbc.execute('DROP TABLE IF EXISTS localizations')

# Prepare table
dbc.execute('CREATE TABLE IF NOT EXISTS "localizations" ('
    '"language" TEXT NOT NULL COLLATE NOCASE,'
    '"token" TEXT NOT NULL COLLATE NOCASE,'
    '"string" TEXT,'
    'PRIMARY KEY ("language", "token"))'
)

total_local_strings = 0

for localization_file in LANGUAGE_FILES:
    # Decode VDF.  It has UCS2 encoding, so decode it as such
    tokens_included = 0
    data = vdf.parse(open(localization_file, 'r', encoding='utf-16'))
    data = data['lang']
    
    language = data['Language'].lower()
    for k, v in data['Tokens'].items():
        if not (k.startswith('[english]') and DROP_LOCALIZED_ENGLISH_TOKEN):
            dbc.execute('INSERT OR REPLACE INTO localizations (language,token,string) VALUES (?,?,?)', (language, k, v) )
            
            tokens_included += 1

    db.commit()
    print('Localization file for {} ({}) has {} string entries (inserted {})'.format(data['Language'], os.path.basename(localization_file), len(data['Tokens']), tokens_included))
    total_local_strings += tokens_included

for localization_file in LANGUAGE_FILES_KOREANA:
    # Decode VDF.  It has UCS2 encoding, so decode it as such
    tokens_included = 0
    data = vdf.parse(open(localization_file, 'r', encoding='utf-16'))
    data = data['lang']
    
    data['Language'] = 'koreana'
    
    language = data['Language'].lower()
    for k, v in data['Tokens'].items():
        if not (k.startswith('[english]') and DROP_LOCALIZED_ENGLISH_TOKEN):
            dbc.execute('INSERT OR REPLACE INTO localizations (language,token,string) VALUES (?,?,?)', (language, k, v) )
            
            tokens_included += 1

    db.commit()
    print('Localization file for {} ({}) has {} string entries (inserted {})'.format(data['Language'], os.path.basename(localization_file), len(data['Tokens']), tokens_included))
    total_local_strings += tokens_included


# Just do some housekeeping for size
print('Performing a VACUUM on the database.')
dbc.execute('VACUUM')
db.commit()

print('{} localization strings submitted to database.'.format(total_local_strings))