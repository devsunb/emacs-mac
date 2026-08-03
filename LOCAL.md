# 로컬 패치 기록

커밋별 증상과 방법은 커밋 본문에 있다. 여기에는 커밋 하나에 속하지 않거나 코드와 커밋을 봐도 알 수 없는 근거만 둔다.

## 커밋 사이의 런타임 의존

충돌로 드러나지 않는 의존만 적는다. 패치 문맥 충돌은 rebase가 알려 준다.

- 데몬 커밋은 마지막 GUI 프레임이 지워지면 활성화 정책을 Prohibited로 내린다. 그것을 Regular로 되돌리는 코드는 활성화 커밋뿐이다. 활성화 커밋 없이 데몬 커밋만 두면 프레임을 다시 만들 수 없다.
- 데몬 커밋의 warm-up 프레임은 `(alpha . 0)`으로 만든다. alpha 커밋이 없으면 창이 만들어진 뒤에야 alpha가 적용되어 데몬 시작 때 프레임이 번쩍인다.
- flush 커밋의 테스트는 배율 1 커밋이 `ENABLE_CHECKING` 아래에 넣은 테스트용 DEFUN을 부른다. 배율 1 커밋을 버리면 flush 커밋의 테스트도 함께 떼어 낸다.
- 알림 커밋과 flush 커밋은 각각 데몬 커밋과 배율 1 커밋이 새로 만든 테스트 파일을 고친다. 앞 커밋을 버릴 때는 뒤 커밋의 테스트 변경을 먼저 떼어 내야 modify/delete 충돌이 나지 않는다.

## 실측으로만 알아낸 macOS 동작

- 활성화 정책을 `mac_term_init`이나 `[NSApp run]` 직후에 바꾸면 warm-up 프레임을 지운 뒤 Dock 타일이 고착된다. 그래서 정책 변경을 첫 idle까지 미룬다.
- 마지막 GUI 프레임 삭제로 Prohibited가 되면 AppKit이 비동기로 hide 알림을 보낸다. 이 알림을 사용자의 hide로 세면 다음 reopen이 헛돈다. `applicationHiddenExplicitly`가 그 구분이다.
- macOS 14 이상에서 인자 없는 `[NSApp activate]`는 다른 앱이 최전면이면 포커스를 얻지 못한다. `activateFromApplication:`은 얻는다. 다만 emacsclient를 최전면 앱과 무관한 셸에서 부르면 프레임은 뜨되 key가 되지 않는다.
- 무서명이거나 서명이 깨진 번들에서도 `UNUserNotificationCenter` 초기화와 카테고리 등록은 성공한다. 번들 서명이 필요한 것은 인가 요청과 배달이다. 번들 밖 `src/emacs`는 bundleIdentifier가 nil이라 알림을 아예 쓸 수 없다.
- 배너 클릭으로 앱이 기동될 때의 응답은 기동이 끝나기 전에 delegate가 있어야 받는다. 그래서 delegate 등록을 첫 notify로 미루지 않고 `applicationDidFinishLaunching:`에서 한다.
- 알림 응답의 완료 핸들러를 메인 큐 블록 안에서 부르면 Lisp 스레드가 계산 중일 때 완료 보고가 `mac_select`로 돌아올 때까지 밀린다. 그래서 블록 밖에서 바로 부른다.
- undecorated-round 창에서 창 서버가 타이틀바 드래그 영역으로 잡는 맨 윗줄을 되찾는 방법은 `movable`을 지우는 것뿐이었다. 그래서 Ctrl+Cmd 드래그를 직접 구현한다.
- `performWindowDragWithEvent:`는 즉시 반환하므로 직후의 `movable = NO`는 드래그 도중에 걸린다. 실사용에서 드래그가 되지만 문서화된 계약은 아니다.

## build.sh 전제

- `Contents/MacOS/libexec`를 `Contents/Resources` 밑으로 옮기고 심링크를 남기는 것은 codesign 때문이다. `MacOS` 아래의 `libexec/<configuration>`을 하위 컴포넌트로 취급해 번들 서명이 "bundle format unrecognized"로 실패하고, `Resources` 아래에 두면 데이터로 봉인된다.
- `Resources/lib/systemd` 삭제는 configure.ac가 self-contained 분기에서 비운 `INSTALL_ARCH_INDEP_EXTRA`를 뒤에서 `install-etc`로 무조건 덮어쓰는 upstream 결함 때문이다.
- PlistBuddy의 `Set :CFBundleIconFile`은 키가 있어야, `Add :CFBundleIconName`은 키가 없어야 성공한다. mac/templates/Info.plist.in에 `CFBundleIconFile`만 있다는 전제다. upstream이 `CFBundleIconName`을 템플릿에 넣으면 `Add`를 `Set`으로 바꾼다.
- `Assets.car`와 `CFBundleIconName`은 macOS 26 이상에서만 쓰인다. 지금 호스트에서는 `EmacsLG1-Default.icns`만 쓰인다. OS 업데이트 대비로 함께 둔다.
- staging 디렉터리는 EXIT 트랩으로만 지우므로 SIGKILL이나 전원 차단에서는 `out/.Emacs.install.*`이 남는다. staging 생성 직전에 잔재를 지우는 줄이 그 대응이고, build.sh 두 인스턴스를 동시에 돌리지 않는다는 전제다.

## 검증 함정

- in-tree `src/emacs`는 self-contained 배치를 전제로 빌드되어 번들 밖에서는 lisp 디렉터리를 못 찾는다. 테스트와 데몬 실행 모두 `EMACSLOADPATH`에 소스 트리 `lisp`와 그 하위 디렉터리를 전부 넣어야 한다. 데몬은 `server`도 미리 적재되지 않아 이것이 없으면 프레임이 아니라 데몬 자체가 뜨지 않는다.
- 실사용 데몬과 부딪히지 않게 `--daemon=<이름>`과 `emacsclient -s <이름>`을 쓴다.
- Dock 클릭은 외부 프로세스에서 `rapp` Apple Event를 보내 재현한다. 자기 pid로 보내면 -1712 타임아웃이 난다.
- `term/mac-win`은 pdmp에 미리 적재되어 `EMACSLOADPATH`로 바꿔 끼울 수 없다. mac-win-tests.el 첫머리가 `EMACS_TEST_DIRECTORY` 기준으로 `mac-win.el`을 다시 읽으므로 그 변수를 대상 트리로 두면 런타임 재정의로 갈아 끼울 수 있다.
- test/manual의 GUI 테스트를 명령줄에서 돌리려면 `EMACSLOADPATH`를 절대 경로로 주고 테스트 실행을 `emacs-startup-hook` 뒤의 타이머로 미룬다. 창 시스템이 켜진 채 stdin이 tty가 아니면 emacs.c가 홈으로 chdir 하고, `--eval`로 기동 중에 곧바로 돌리면 결과 없이 멈춘다.
- test/manual의 이미지 테스트는 `--enable-checking` 빌드에서만 돈다. build.sh의 configure에는 그 옵션이 없어 별도 빌드가 필요하다.
- 이 저장소는 `rerere.enabled=true`라 체리픽과 `git apply --3way`의 충돌이 조용히 자동 해소된다. 순서 제약을 재확인할 때는 `git -c rerere.enabled=false`를 쓴다.
- local 커밋은 바이너리 파일을 담으므로 패치를 만들 때 `git show --binary`가 필요하다.
