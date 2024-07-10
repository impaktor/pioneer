"""This script does two things:
 1. identify translatd strings with errors in substitution variables
    (typos, translation, malformed, missing)

 2. where number of substitution variables in translated and english
    string are the same, assume it's a typo, or they've translated the
    variable name. Note: we assume strings where substitution
    variables are in different order are correct.
"""

import glob
import json
import os
import re
from loguru import logger

# 2024-07-03 14:19:40.474 | DEBUG    | __main__:compare_file:127 - translated: OVER_N_BILLION, ['{population}']
# 2024-07-03 14:19:40.474 | DEBUG    | __main__:compare_file:128 - correct:    OVER_N_BILLION, ['%population']
# 2024-07-03 14:19:40.474 | DEBUG    | __main__:fix_single_typo:96 - guess: %population, wrong: {population}
# 2024-07-03 14:19:40.474 | DEBUG    | __main__:fix_single_typo:98 - suggested: ['%population']
# 2024-07-03 14:19:40.501 | INFO     | __main__:fix_file:215 - old: Alrededor de %{population}000 millones
# 2024-07-03 14:19:40.501 | INFO     | __main__:fix_file:217 - new: Alrededor de %%population000 millones

# For dev-ing:
# text = """Přestože konfliktní strany v systému {systém} ({sectorx}, {sectorx}, bar {sectorz}) nepodepsaly oficiální příměří, dohodly se přestat používat chemické zbraně"""
# print(text)
# replace_with = ["{system}", "{sectorx}", "{sectory}", "{sectorz}"]

files_en = glob.glob("data/lang/**/en.json", recursive=True)
files_all = glob.glob("data/lang/**/*.json", recursive=True)

# Sort on language, then on module
files_en = sorted(files_en, key=lambda x: os.path.basename(x) + os.path.dirname(x))
files_all = sorted(files_all, key=lambda x: os.path.basename(x) + os.path.dirname(x))


def parse_str_lua(s: str) -> list:
    """Retrieve all '{foo}' (lua variables) in string"""
    # s = [m[1:-1] for m in re.findall(r"{.*?}", s)]
    return re.findall(r"{.*?}", s)


def parse_str_cpp(s: str) -> list:
    """Retrieve all '%foo' (c++ variables) in string"""
    # s = [m[1:] for m in re.findall(r"\B[%]\w+", s)]
    return re.findall(r"\B[%]\w+", s)


def parse_str_all(s: str) -> list:
    """Find all %foo and {foo} in strings"""
    return re.findall(r"{.*?}|\B[%]\w+", s)


def parse_file(json_file: str) -> dict:
    """Get dict of all translation key: values on form:
    {TRANS_KEY1: [var1, var2, ...], TRANS_KEY2: [var1, var2, ...], ...}
    """
    strings = {}
    with open(json_file) as f:
        for key, value in json.load(f).items():
            s = value["message"]
            # Assuming we want to ignore false postives from "50 %foo",
            # outside core. C++ only does substitution in core/*json:
            if "data/lang/core" in os.path.dirname(json_file):
                trans_keys = parse_str_all(s)
            else:
                trans_keys = parse_str_lua(s)
            if not trans_keys:
                continue
            strings[key] = trans_keys
    return strings


def fix_single_typo(corr: list, tran: list) -> list:
    """Order of placeholders in translated strings can differ. When
    only one placeholder is wrong, we know with what to replace it
    with:

    Cases to handle ('correct' = English):
    corr     = ["{foo}", "{bar}"]
    tran     = ["{xxx}", "{foo}"]
    suggest -> ["{foo}", "{baz}"]

    corr     = ["{foo}", "{bar}", "{bar}"]
    tran     = ["{bar}", "{xxx}", "{foo}"]
    suggest -> ["{bar}", "{baz}", "{foo}"]

    Don't cover:
    corr     = ["{foo}", "{bar}"]
    tran     = ["{bar}", "{bar}"]
    """

    corr_unique = set(corr)
    tran_unique = set(tran)

    assert len(corr_unique - tran_unique) == 1
    assert len(tran_unique - corr_unique) == 1

    wrong = (tran_unique - corr_unique).pop()
    guess = (corr_unique - tran_unique).pop()

    logger.debug(f"guess: {guess}, wrong: {wrong}")
    suggest = [guess if x == wrong else x for x in tran]
    logger.debug(f"suggested: {suggest}")
    return suggest


def compare_file(corr: dict, tran: dict) -> dict:
    """Compare dict {KEY1: ['{foo}' '%bar'], ...} of all keys from a
    file, with correct (en) and translated. Return list of tuples,
    with original and suggested replacement placeholders
    """

    errors, warnings = 0, 0
    to_fix = {}
    for key, _ in corr.items():

        if key not in tran:
            errors += 1
            logger.error(
                f"ERROR: {key} placeholder(s) missing/invalid missing: {corr[key]}"
            )
            continue

        if corr[key] != tran[key]:

            if set(corr[key]) == set(tran[key]):
                # allow arbitrary order of keys in strings
                warnings += 1
                logger.warning(f"translated: {key}, {tran[key]}")
                logger.warning(f"correct:    {key}, {corr[key]}")
            elif len(corr[key]) == len(tran[key]):
                logger.debug(f"translated: {key}, {tran[key]}")
                logger.debug(f"correct:    {key}, {corr[key]}")

                if (
                    len(set(corr[key]) - set(tran[key])) == 1
                    and len(set(tran[key]) - set(corr[key])) == 1
                ):
                    # If just one of the placeholders differ, assume typo,
                    # and preserve order in translated string
                    # orig = ['{foo}', '{bar}']
                    # tran = ['{bar}', '{xxx}']
                    suggested = fix_single_typo(corr[key], tran[key])
                elif (
                    len(set(corr[key]) - set(tran[key])) == 1
                    and len(set(tran[key]) - set(corr[key])) == 0
                ):
                    # orig = ['{foo}', '{bar}']
                    # tran = ['{bar}', '{bar}']
                    suggested = corr[key]
                else:
                    # brute force, but only if number of placeholders match,
                    # e.g. they've probably translated all placeholders
                    suggested = corr[key]
                to_fix[key] = suggested
                errors += 1
            else:
                # missing one or several substitution varialbes,
                # might be intentional or error, no suggested fix.
                errors += 1
                logger.debug(f"translated: {key}, {tran[key]}")
                logger.debug(f"correct:    {key}, {corr[key]}")

    print(f"errors: {errors}, warnings: {warnings}", end="\n")
    return to_fix


def find_errors(files_en, files_all):

    # all strings keyed on file name
    strings_en = {json_file: parse_file(json_file) for json_file in files_en}
    strings_all = {json_file: parse_file(json_file) for json_file in files_all}

    files_to_fix = {}

    # compare with en.json (assumption of identical sort order should be fine):
    for file_name_tr, file_placeholders in strings_all.items():
        file_name_en = os.path.dirname(file_name_tr) + "/en.json"
        if strings_en[file_name_en] != file_placeholders:
            logger.debug(f" in file: {file_name_tr} \n")
            errors = compare_file(strings_en[file_name_en], file_placeholders)

            # Not all errors are fixable
            if errors:
                files_to_fix[file_name_tr] = errors

    return files_to_fix


def fix_string(text: str, corrections: list) -> str:
    """Fix 'text' by replacing varibales with the ones pulled from
    original english strings."""

    cache = ""
    last_end = 0
    for i, m in enumerate(re.finditer(r"{.*?}|\B[%]\w+", text)):
        logger.trace(
            f"i={i}, start={m.start()}, end={m.end()}, orig={m.group(0)}, replace={corrections[i]}"
        )
        cache += text[last_end : m.start()] + corrections[i]
        last_end = m.end()

    return cache + text[last_end:]


def fix_file(json_file: str, suggested):

    # open file translated, and file english
    with open(json_file, "r+", encoding="utf8") as ft:
        new_dict = {}
        for key, value in json.load(ft).items():
            st_dsc = value["description"]
            st_msg = value["message"]

            if key in list(suggested.keys()):
                # list of correct variables for sentence st
                # replace_with = correct_placeholders[en_file][key]
                replace_with = suggested[key]

                logger.info(f"old: {st_msg}")
                st_msg = fix_string(st_msg, replace_with)
                logger.info(f"new: {st_msg}")

            new_dict[key] = {
                "description": st_dsc,
                "message": st_msg,
            }

        # Write back to file:
        # ft.seek(0)
        # json.dump(new_dict, ft, indent=2, ensure_ascii=False)
        # ft.write("\n")
        # ft.truncate()


files_to_fix = find_errors(files_en, files_all)
languages = set()


for f, suggested in files_to_fix.items():
    languages.add(os.path.basename(f))
    fix_file(f, suggested)

for l in languages:
    print(l)



Brazilian Portuguese(pt_BR), Chinese (zh), Czech (cs), Danish (da), Dutch (nl) French (fr), German (de), Hungarian (hu), Italian (it), Polish (pl), Portugese (pt), Russian (ru), Spanish (es), Swedish (sv),
