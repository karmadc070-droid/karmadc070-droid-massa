#!/usr/bin/env python3
# cap add android 가 만든 build.gradle 에 릴리스 서명 설정을 끼워 넣는다 (Codemagic 빌드용).
#
# 왜 파일로 뺐나 — codemagic.yaml 안에 파이썬을 인라인으로 넣었더니 여러 줄 문자열의
# 들여쓰기가 YAML 블록 스칼라를 끊어서 전체 파일이 깨졌다. 스크립트는 파일로 둔다.
#
# 값은 gradle.properties 에서 읽는다. 비밀번호를 이 파일에 적지 않는다.

import re
import sys

GRADLE = "android/app/build.gradle"

SIGNING = """
    signingConfigs {
        release {
            storeFile file(MASSA_STORE_FILE)
            storePassword MASSA_STORE_PASSWORD
            keyAlias MASSA_KEY_ALIAS
            keyPassword MASSA_KEY_PASSWORD
        }
    }
"""


def main() -> int:
    try:
        src = open(GRADLE, encoding="utf-8").read()
    except FileNotFoundError:
        print(f"★ {GRADLE} 이 없다 — cap add android 가 먼저 돌아야 한다")
        return 1

    if "MASSA_STORE_FILE" in src:
        print("이미 서명 설정이 들어 있다 — 건너뛴다")
        return 0

    # android { 바로 뒤에 signingConfigs 를 넣는다
    out, n = re.subn(r"android\s*\{", lambda m: m.group(0) + SIGNING, src, count=1)
    if n != 1:
        print("★ 'android {' 블록을 찾지 못했다")
        return 1

    # release 빌드타입에 서명을 건다
    out, n = re.subn(
        r"(buildTypes\s*\{\s*release\s*\{)",
        r"\1\n            signingConfig signingConfigs.release",
        out,
        count=1,
    )
    if n != 1:
        print("★ buildTypes.release 를 찾지 못했다")
        return 1

    open(GRADLE, "w", encoding="utf-8").write(out)
    print("서명 설정 주입 완료")
    return 0


if __name__ == "__main__":
    sys.exit(main())
