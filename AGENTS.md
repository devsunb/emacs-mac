# emacs-mac 개인 fork 작업 지침

## 저장소 목적

- [jdtsmith/emacs-mac](https://github.com/jdtsmith/emacs-mac)을 fork한 저장소다. 개인 사용을 위해 몇 가지 패치를 더해 빌드한다.
- upstream(`upstream` remote)을 계속 추적한다. rebase conflict 부담을 줄이기 위해 diff를 최소화한다.
- upstream에 PR을 보내는 것은 목표가 아니다.
- upstream의 AGENTS.md(LLM 코드 생성 금지 정책)는 이 fork에 적용하지 않는다. rebase 때 이 파일이 충돌하면 우리 내용을 유지한다.
- 로컬 패치는 main 한 스택이다. 지금 겪는 문제를 고치는 커밋만 둔다.
- 사실이지만 지금 겪지 않는 문제는 고치지 않는다. 이미 고친 커밋은 `archive/<이름>` 태그로 보관하고 main에서 뺀다. 태그는 유지 관리하지 않고, 필요해지면 cherry-pick 한다.
- 새 문제를 고치기 전에 `git tag -n1 -l 'archive/*'`로 보관된 해결책이 있는지 먼저 본다.

## 변경 원칙

- emacs-mac을 수정하지 않고 emacs.d에서 해결할 수 있으면 emacs.d로 옮긴다.
- 문제를 해결하는 선에서 가장 적은 diff를 목표로 한다.
- 반드시 필요한 상황이 아니면 주석을 추가하지 않는다.

## 기록 원칙

- 커밋 제목은 식별용 한 줄 요약이다. 본문에 증상과 고친 방법, 다른 커밋에 대한 런타임 의존을 한두 문장으로 적는다. upstream이 같은 문제를 고쳤을 때 커밋을 버릴 수 있는지 대조하기 위한 것이다.
- 패치에 대한 설명이 반드시 필요하면 `LOCAL.md`에 기록한다. 코드만 보고 알 수 없는 근거만 적는다.
- 코드를 읽거나 명령을 실행하면 바로 알 수 있는 값(상수, 경로, 버전, 커밋 개수 등)은 기록하지 않는다. 값이 달라졌을 때 기록을 찾아 고쳐야 하는 부담이 생기기 때문이다.

## 사용자 환경

이 fork는 아래 환경만 지원하면 된다. 아래 환경에서 도달하지 않는 코드는 upstream 상태를 유지한다.

- GUI로만 쓴다. 터미널 Emacs는 쓰지 않는다.
- 부팅할 때 데몬 하나를 띄운다. 프레임은 emacsclient 또는 Emacs.app 으로 연다. Emacs.app은 빌드 산출물인 macOS 앱이며, 데몬이 실행 중일 때 앱을 실행하면 자동으로 그 데몬에 붙는다.
- 한글 IME를 쓴다.
- 맥북 Retina 모니터와 FHD 외장 모니터를 함께 쓴다. Retina 화면에서 찍은 스크린샷 PNG를 Emacs에서 본다.
- 터미널은 ghostel로 Emacs 안에서 쓴다.
- `make-thread`는 아직 쓰지 않지만 앞으로 쓸 예정이다.
- 휠 스크롤은 ultra-scroll 패키지가 처리한다. modifier 키가 눌린 휠 이벤트만 Emacs 전역 키 바인딩으로 간다.
- Ctrl+Cmd 드래그로 macOS 창 위치를 이동한다. Emacs가 이 드래그를 가로채면 안 된다.
- Hammerspoon 연동에 Apple Event(event class `HmSp`, event ID `EXEC`)를 사용한다.
