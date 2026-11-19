#!/usr/bin/env python3
"""korean-ste linter — deterministic checks for one Korean document.

Usage:
  python3 lint.py --profile strict|standard|consistency [--terms FILE ...] DOC

Rules:
  TERM   a variant from a term map is used instead of its canonical term
  STYLE  speech levels (합쇼체 / 해요체 / 해라체) are mixed
  UNIT   one unit is written in different spellings or spacings
  CODE   an identifier written in backticks elsewhere appears bare
  LEN    a sentence is longer than the profile allows (in 어절)
  MULTI  a sentence chains more than one action                   (strict)
  COND   a condition comes after the instruction ("단, ~")        (strict)
  VAGUE  a vague qualifier hides the real condition or action     (strict)

Exit code: 0 when clean, 1 when there are findings, 2 on usage error.
"""
import argparse
import re
import sys
from collections import Counter

LIMITS = {
    "strict": 20,
    "standard": 25,
    "consistency": None,
}

NOT_HANGUL_BEFORE = r"(?<![가-힣A-Za-z0-9])"
INLINE_CODE = re.compile(r"`[^`\n]+`")
LINK = re.compile(r"\[([^\]]*)\]\([^)]*\)")
LIST_MARKER = re.compile(r"^\s*(?:[-*+]|\d+[.)]|>)\s+")
SENTENCE_END = re.compile(r"(?<=[.?!])\s+")
IDENTIFIER = re.compile(r"^[A-Za-z_][\w.\-/:()]*$")

UNIT_FAMILIES = {
    "분": ["분", "min", "mins", "minute", "minutes"],
    "초": ["초", "s", "sec", "secs", "second", "seconds"],
    "시간": ["시간", "h", "hr", "hrs", "hour", "hours"],
    "밀리초": ["밀리초", "ms"],
    "퍼센트": ["%", "퍼센트", "프로"],
}

CONNECTIVE = re.compile(r"[가-힣](?<![라다자])고(?:\s나서)?[\s,]|[가-힣]며[\s,]")
AFTER = re.compile(r"(\S+)\s(?:뒤|후|다음)(?:에|에는)?[\s,]")
TRAILING_CONDITION = re.compile(r"^(?:단|다만)[,\s]")
VAGUE = re.compile(
    r"적절히|적절한|적당히|필요\s?시|필요에 따라|가능하면|가급적|상황에 따라|"
    r"하도록 한다|하도록 합니다|할 것을 권장|하는 것이 좋다|하는 것이 좋습니다"
)


def main() -> int:
    parser = argparse.ArgumentParser(description="korean-ste linter")
    parser.add_argument("--profile", required=True, choices=LIMITS.keys())
    parser.add_argument("--terms", action="append", default=[], help="term map file (repeatable)")
    parser.add_argument("doc")
    args = parser.parse_args()

    lines = read_prose_lines(args.doc)
    terms = read_term_maps(args.terms)
    sentences = split_sentences(lines)

    findings = []
    findings += check_terms(lines, terms)
    findings += check_style(sentences)
    findings += check_units(lines)
    findings += check_code(lines)
    if LIMITS[args.profile]:
        findings += check_length(sentences, LIMITS[args.profile])
    if args.profile == "strict":
        findings += check_strict(sentences)

    findings.sort(key=lambda it: (it[0], it[1]))
    for lineno, rule, message, excerpt in findings:
        print(f"L{lineno} [{rule}] {message} | {excerpt}")
    counts = Counter(it[1] for it in findings)
    summary = ", ".join(f"{rule} {count}" for rule, count in sorted(counts.items()))
    print(f"total {len(findings)}" + (f" ({summary})" if summary else ""))
    return 1 if findings else 0


def read_prose_lines(path):
    """(lineno, text, kind) for every line outside code fences. kind: heading | table | prose."""
    result = []
    in_fence = False
    with open(path, encoding="utf-8") as file:
        for lineno, raw in enumerate(file, start=1):
            text = raw.rstrip("\n")
            if text.lstrip().startswith(("```", "~~~")):
                in_fence = not in_fence
                continue
            if in_fence or not text.strip():
                continue
            stripped = text.lstrip()
            kind = "heading" if stripped.startswith("#") else "table" if stripped.startswith("|") else "prose"
            result.append((lineno, text, kind))
    return result


def read_term_maps(paths):
    """{variant: canonical} from lines like `- 대표어: 변형1, 변형2`."""
    terms = {}
    for path in paths:
        with open(path, encoding="utf-8") as file:
            for raw in file:
                line = LIST_MARKER.sub("", raw.strip())
                if not line or line.startswith("#") or ":" not in line:
                    continue
                canonical, variants = line.split(":", 1)
                canonical = canonical.strip().strip("`")
                for variant in variants.split(","):
                    variant = variant.strip().strip("`")
                    if variant and variant != canonical:
                        terms[variant] = canonical
    return terms


def split_sentences(lines):
    """(lineno, sentence) for prose lines, markdown markers and links removed."""
    result = []
    for lineno, text, kind in lines:
        if kind != "prose":
            continue
        body = LINK.sub(r"\1", LIST_MARKER.sub("", text)).strip()
        for sentence in SENTENCE_END.split(body):
            if sentence.strip():
                result.append((lineno, sentence.strip()))
    return result


def check_terms(lines, terms):
    findings = []
    for variant, canonical in terms.items():
        tail = r"(?![A-Za-z0-9])" if variant.isascii() else ""
        pattern = re.compile(NOT_HANGUL_BEFORE + re.escape(variant) + tail)
        for lineno, text, _ in lines:
            if pattern.search(INLINE_CODE.sub("", text)):
                findings.append((lineno, "TERM", f"'{variant}' → '{canonical}'", text.strip()))
    return findings


def check_style(sentences):
    levels = []
    for lineno, sentence in sentences:
        level = speech_level(sentence)
        if level:
            levels.append((lineno, level, sentence))
    counts = Counter(it[1] for it in levels)
    if len(counts) < 2:
        return []
    majority = counts.most_common(1)[0][0]
    return [
        (lineno, "STYLE", f"{level} — 문서 대부분은 {majority}", sentence)
        for lineno, level, sentence in levels
        if level != majority
    ]


def speech_level(sentence):
    words = INLINE_CODE.sub("X", sentence).rstrip(" .?!\"')]").split()
    if not words:
        return None
    last = words[-1]
    if last.endswith(("니다", "니까", "십시오", "시오")):
        return "합쇼체"
    if last.endswith("요"):
        return "해요체"
    if last.endswith("다") and re.search(r"[.?!]$", sentence):
        return "해라체"
    return None


def check_units(lines):
    findings = []
    numeric = re.compile(r"(?<![\w.])\d[\d,]*(?:\.\d+)?(\s?)")
    for family, spellings in UNIT_FAMILIES.items():
        uses = []
        for lineno, text, _ in lines:
            prose = INLINE_CODE.sub("", text)
            for spelling in spellings:
                tail = r"(?![A-Za-z])" if spelling.isascii() else ""
                pattern = re.compile(numeric.pattern + "(" + re.escape(spelling) + ")" + tail)
                for match in pattern.finditer(prose):
                    uses.append((lineno, match.group(2), bool(match.group(1)), match.group(0)))
        findings += minority(uses, 1, "UNIT", lambda it: f"'{family}' 표기가 섞임: '{it}'")
        for spelling in spellings:
            same_spelling = [it for it in uses if it[1] == spelling]
            findings += minority(same_spelling, 2, "UNIT", lambda it: f"숫자와 '{spelling}' 사이 띄어쓰기가 섞임")

    comma_numbers = re.compile(r"(?<![\w.])\d{1,3}(?:,\d{3})+(?![\d])")
    bare_numbers = re.compile(r"(?<![\w.,:\-])\d{4,}(?![\d,:\-])")
    prose_lines = [(lineno, INLINE_CODE.sub("", text)) for lineno, text, _ in lines]
    if any(comma_numbers.search(text) for _, text in prose_lines):
        for lineno, text in prose_lines:
            for match in bare_numbers.finditer(text):
                if not re.fullmatch(r"(?:19|20)\d\d", match.group(0)):
                    findings.append((lineno, "UNIT", "천 단위 쉼표가 빠짐", match.group(0)))
    return findings


def minority(uses, index, rule, message):
    counts = Counter(it[index] for it in uses)
    if len(counts) < 2:
        return []
    majority = counts.most_common(1)[0][0]
    return [(it[0], rule, message(it[index]), it[3].strip()) for it in uses if it[index] != majority]


def check_code(lines):
    tokens = set()
    for _, text, _ in lines:
        for match in INLINE_CODE.finditer(text):
            token = match.group(0).strip("`")
            if IDENTIFIER.match(token) and len(token) >= 3:
                tokens.add(token)
    findings = []
    for token in sorted(tokens):
        pattern = re.compile(r"(?<![\w`])" + re.escape(token) + r"(?![\w`])")
        for lineno, text, _ in lines:
            if pattern.search(LINK.sub("", INLINE_CODE.sub("", text))):
                findings.append((lineno, "CODE", f"'{token}'에 backtick이 빠짐", text.strip()))
    return findings


def check_length(sentences, limit):
    findings = []
    for lineno, sentence in sentences:
        count = len([it for it in INLINE_CODE.sub("X", sentence).split() if re.search(r"\w", it)])
        if count > limit:
            findings.append((lineno, "LEN", f"{count}어절 (최대 {limit})", sentence))
    return findings


def check_strict(sentences):
    findings = []
    for lineno, sentence in sentences:
        prose = INLINE_CODE.sub("X", sentence)
        if chains_actions(prose + " "):
            findings.append((lineno, "MULTI", "한 문장에 행동이 여러 개", sentence))
        if TRAILING_CONDITION.search(prose):
            findings.append((lineno, "COND", "조건이 지시 뒤에 옴", sentence))
        for match in VAGUE.finditer(prose):
            findings.append((lineno, "VAGUE", f"모호한 표현 '{match.group(0)}'", sentence))
    return findings


def chains_actions(text):
    """'-고', '-며', or a verb in ㄴ form before 뒤/후/다음 ('확인한 뒤'). '반영 후', '10분 후' do not count."""
    if CONNECTIVE.search(text):
        return True
    return any(
        ends_with_n_final(it.group(1)) and not re.search(r"\d", it.group(1))
        for it in AFTER.finditer(text)
    )


def ends_with_n_final(word):
    last = word[-1]
    return "가" <= last <= "힣" and (ord(last) - 0xAC00) % 28 == 4


if __name__ == "__main__":
    sys.exit(main())
