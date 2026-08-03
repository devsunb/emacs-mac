# 로컬 패치

이 문서는 upstream(`emacs-mac-gnu_master_exp`) 대비 로컬 패치 커밋을 기록한다.
리베이스로 해시가 바뀔 수 있으므로 커밋 제목으로 식별한다.
분류 기준은 `CLAUDE.md`에 있다.
현재 구성은 **main 11개, dev 17개**다.
dev는 main이 아니라 upstream 베이스 바로 위에 얹힌 독립 파킹 스택이다.
main 심볼에 의존하는 커밋이 셋 있다. 셀렉터와 최소화는 코드가 의존해 dev 단독으로는 빌드되지 않고, `@2x` 파일은 테스트만 의존해 빌드에는 영향이 없다.
dev는 업스트림 동기화 때 리베이스하지 않고, 다시 필요해지면 main으로 체리픽한다.

표는 스택 순서와 한 줄 트리거만 담고, 그 밖의 판단 정보는 커밋별 소절에 항목별로 둔다.
항목이 없는 커밋은 소절을 두지 않는다.

## 사용 조건

GUI로만 쓰고 터미널 Emacs는 쓰지 않는다. 부팅할 때 데몬 하나를 띄우고 emacsclient와 Emacs.app을 쓴다. 한글 IME를 쓴다.
Retina와 비-Retina 외장 모니터를 함께 쓰고, WebP 이미지를 본다. 맥북 화면과 Retina 화면에서 찍은 스크린샷 PNG도 Emacs에서 본다. play-sound는 쓰지 않는다(소리가 필요하면 알림의 `:sound`로 낸다).
커서는 `cursor-type`을 bar로 쓴다.
프레임을 최소화한 채 fullscreen 파라미터를 바꾸고 Dock으로 되살리는 일이 있다.
터미널은 ghostel로 Emacs 안에서 쓴다(로컬 버퍼는 네이티브 모듈이 pty를 직접 읽고, Emacs의 pty 읽기 경로는 원격 버퍼나 옵션을 껐을 때만 지난다). `make-thread`는 아직 쓰지 않지만 앞으로 쓸 예정이다.
마우스를 피하고 키보드 중심으로 쓴다. 스크롤은 ultra-scroll이 맡고, 수식어가 붙은 휠만 전역 바인딩을 거친다. 다만 `undecorated-round` 프레임은 Ctrl+Cmd 드래그로 옮긴다.
Hammerspoon 연동(AppleScript가 아니라 Apple Event `HmSp`/`EXEC` 직접 전송) 코드는 tmp/sunb에 있으나 지금 init은 적재하지 않는다.
LaTeX 도구는 설치하지 않았다. secondary selection은 쓰지 않는다.

## 검증

- 배치: `mac-win-tests`가 통과한다(main 12/12). 설치된 Emacs.app으로도 돌릴 수 있다(`EMACS_TEST_DIRECTORY=$PWD/test`).
  in-tree `src/emacs`는 self-contained 배치를 전제로 빌드되어 번들 밖에서는 lisp 디렉터리를 못 찾는다.
  미리 적재되지 않은 라이브러리를 쓰는 테스트는 `EMACSLOADPATH`에 소스 트리 `lisp`의 하위 디렉터리를 전부 넣어야 한다.
- 실동작: `src/emacs -Q --daemon`과 `emacsclient -c`로 데몬에서 GUI 프레임이 생기는지 확인한다.
  데몬도 `server`가 미리 적재되지 않으므로 배치 항목의 `EMACSLOADPATH`를 소스 트리 `lisp` 자체까지 포함해 주어야 하고, 주지 않으면 프레임이 아니라 데몬 자체가 뜨지 않는다.
  실사용 데몬과 부딪히지 않게 `--daemon=<이름>`으로 고유한 서버 이름을 주고 `emacsclient -s <이름>`으로 붙는다.
  번들 밖 실행이므로 활성화 정책 커밋도 함께 검증된다.
  `undecorated-round` 프레임이 만들어지는지, `mac-notifications-notify`가 있는지도 확인한다.
- 함정: Dock 클릭은 외부 프로세스에서 `rapp` Apple Event를 보내 재현한다(자기 pid로 보내면 -1712 타임아웃이 난다).
  `term/mac-win`은 pdmp에 미리 적재되므로 `EMACSLOADPATH`로 바꿔 끼울 수 없다.
  다만 테스트 파일 첫머리가 `EMACS_TEST_DIRECTORY` 기준으로 `mac-win.el`을 소스로 다시 읽으므로, 그 변수를 대상 트리로 두면 런타임 재정의로 갈아 끼울 수 있다.
  리포에 `rerere.enabled=true`가 켜져 있어 체리픽과 `git apply --3way`의 충돌이 조용히 자동 해소된다. 순서 제약을 재확인할 때는 `git -c rerere.enabled=false`를 쓴다.
  local 커밋은 바이너리 파일을 담으므로 단독 적용을 재확인하려면 `git show --binary`로 패치를 만들어야 한다.

## main (11개, 스택 아래부터)

| 커밋 제목 | 트리거 |
|---|---|
| Mac 앱 활성화 정책을 포커스 요청과 분리한다 | 데몬 커밋이 내린 Prohibited 정책 복원. 없으면 마지막 GUI 프레임 삭제 이후(warm-up 포함) Dock 아이콘도 메뉴바도 없고 emacsclient 프레임을 활성화할 수 없음. |
| alpha 프레임 파라미터를 Mac 창을 만든 직후 적용한다 | warm-up 프레임 `(alpha . 0)`의 전제. 없으면 데몬 시작 시 프레임 번쩍임. |
| 데몬 모드에서 GUI 프레임 생성을 지원한다 | 포크의 존재 이유. 데몬에서 GUI 프레임 생성 |
| macOS 데스크톱 알림을 지원한다 | 데스크톱 알림(org 알림 계획). init-mac.el의 org-show-notification-handler가 직접 호출 |
| Mac에서 undecorated-round 프레임 파라미터를 지원한다 | early-init.el의 default-frame-alist에서 사용 중 |
| 명령 루프의 비지역 탈출에서 autorelease 풀을 비운다 | C-g/에러가 톱레벨로 풀릴 때마다 풀 누수, 장기 데몬에 누적 |
| Mac fullscreen 검사를 GUI 스레드 밖으로 미룬다 | 최소화된 프레임의 fullscreen 파라미터를 바꾼 뒤 Dock으로 되살리면 영구 정지(실측) |
| 배율 1 프레임의 Mac 고해상도 이미지 처리를 고친다 | 배율 1 프레임 + DPI 메타데이터 PNG/JPEG에서 매 lookup 재디코드와 캐시 증가 |
| 이미지의 모든 배율 사본을 flush 한다 | 배율 다른 두 화면 병용 시 image-flush가 반대쪽 배율 사본을 못 지움 |
| self-contained Mac 설치에서 DESTDIR을 존중한다 | build.sh의 staging 설치가 의존 |
| local | 개인 파일(build.sh, CLAUDE.md, 이 문서, 아이콘 리소스 3개) + .gitignore 무시 패턴 2줄 |

순서 제약이 있다. 활성화는 데몬보다 아래여야 한다: 데몬은 활성화 커밋이 재구성한 블록 안의 같은 줄(src/macappkit.m)과 활성화 커밋이 지운 extern 자리(src/macterm.h)를 고치므로 3-way로도 활성화 앞으로 옮길 수 없다. 내용 충돌로 순서가 고정되는 커밋은 main에서 데몬뿐이다(알림과 flush도 3-way로 앞에 못 가지만 원인은 앞 커밋이 만든 테스트 파일의 modify/delete 충돌이고 아래에 따로 적었다).
alpha는 패치 문맥 제약이 없고(데몬 뒤로 옮겨도 3-way 무충돌. 실측) warm-up 투명도라는 런타임 의존뿐이라, 같은 브랜치에 있기만 하면 되는 배치 선택이다.
데몬 커밋이 test/lisp/term/mac-win-tests.el을 새로 만드므로, 그 파일을 고치는 알림 커밋은 데몬 뒤에 둔다(C/Lisp 쪽에는 문맥 의존이 없다. 실측).
undecorated-round는 src/macfns.c의 `mac_frame_parm_handlers` 배열 끝에 항목을 더하는데 알림 커밋이 그 배열 바로 뒤에 코드를 넣어 후행 문맥이 바뀌므로, 의미상 의존은 없지만 알림 뒤에 두어야 `git apply`로 적용된다(3-way 머지에서는 순서를 바꿔도 충돌이 없다. 실측).
배율 1 커밋이 test/manual/mac-image-dpi-tests.el을 새로 만들고 flush 커밋이 그 파일에 테스트를 더하므로, flush는 배율 1 뒤에 둔다. src/image.c의 프로덕션 훅은 겹치지 않지만, flush의 테스트가 배율 1 커밋이 `ENABLE_CHECKING` 아래에 넣은 테스트용 DEFUN(`image--set-test-frame-backing-scale-factor`)을 부르므로 의존은 테스트 파일과 테스트용 C 심볼 양쪽에 있고, 테스트 파일 때문에 3-way 체리픽으로도 flush를 배율 1 앞으로 옮길 수 없다(modify/delete 충돌. 실측).
같은 테스트 파일 결합 때문에 데몬이나 배율 1을 통째로 버리면(업스트림이 같은 수정을 채택할 때) 알림과 flush의 테스트 변경이 modify/delete가 되므로, 그때는 뒤 커밋에서 테스트 부분을 떼어 낸 뒤 버린다.
DESTDIR은 존재 이유가 build.sh뿐이라 local 바로 앞에 둔다.
local은 자주 고치는 파일(build.sh, 이 문서)을 위에 얹힌 커밋 없이 고칠 수 있게 맨 뒤에 둔다(다른 커밋과는 어디에 두어도 파일이 겹치지 않는다. 업스트림에 있는 파일은 .gitignore와 CLAUDE.md 두 개이고, 업스트림의 `@AGENTS.md` 한 줄짜리 CLAUDE.md는 이 커밋이 개인 CLAUDE.md로 대체한다).
풀 드레인, fullscreen 지연, DESTDIR은 서로 독립이다. 단독으로 업스트림에 strict `git apply` 되는 커밋은 이 셋에 활성화, alpha, 배율 1, local을 더한 7개이고, 나머지 4개(데몬, 알림, undecorated-round, flush)는 앞 커밋이 있어야 적용된다. 넷을 뺀 나머지 7개도 순서대로 적용된다(실측).

### Mac 앱 활성화 정책을 포커스 요청과 분리한다
- 분류: 데몬 커밋이 main에 있는 조건에서만 main이다.
- 전제: 번들 밖에서 실행한 프로세스는 활성화 정책이 Prohibited이다. Mac 프레임을 모두 잃은 데몬과 같은 조건이다.
- 차이: 활성화 요청 자체는 업스트림 cc53e9e8664의 본문을 그대로 가져왔다(macOS 14 이상은 frontmost 앱에서 활성화를 넘겨받는 `activateFromApplication:options:`, 그 미만은 `activateWithOptions:`). 업스트림 대비 차이는 셋이다: 프로세스가 이미 활성이면 요청을 생략한다(업스트림은 항상 불렀다). `NSApplicationActivateAllWindows`를 넘기지 않아 앱의 다른 창을 들어올리지 않는다(업스트림 `mac_focus_frame`은 대상 창이 최전면이 아니면 넘겼다. 대상 프레임은 별도로 앞에 놓이므로 사용 경로에서는 차이가 없다). 활성화 요청 전에 정책을 Regular로 되돌린다.
- 수정 방식: no-focus 경로가 order-front를 미루는 것은 사용자가 내린 hide를 되돌리지 않기 위해서다. `-unhideWithoutActivation`도 hidden 창을 전부 복원하므로 쓰지 않았다. 툴팁 프레임은 활성화를 요청하지 않는다. 툴팁에는 `no-focus-on-map` 파라미터가 오지 않는데, 툴팁 때문에 활성화하면 최전면 앱에서 포커스를 빼앗기 때문이다.
- 검증: macOS 14 이상에서 인자 없는 `[NSApp activate]`는 다른 앱이 최전면일 때 포커스를 얻지 못했다(과거 실측, 3/3 실패). 이 커밋이 쓰는 `activateFromApplication:`은 최전면 앱에서 활성화를 넘겨받는 다른 API라 그 실패에 해당하지 않고, 데몬 + emacsclient -c에서 프레임이 key가 되는 것을 확인했다(실측 2026-09-01. `activateIgnoringOtherApps:` 방식도 같은 검증을 통과했다).
- 미수정: 최전면 앱이 emacsclient를 부른 프로세스와 무관하면(최전면이 firefox이고 emacsclient를 무관한 백그라운드 셸에서 부른 조건) 프레임은 뜨되 key가 되지 않는다. `frame-focus-state`가 nil이고 `mac-application-state`의 `:active-p`도 nil이다(실측 2026-09-03). `(x-focus-frame f)`를 명시적으로 불러도 같고 번들 데몬으로도 같아서 번들 여부는 원인이 아니다. `activateFromApplication:`에 최전면 앱을 넘기는 활성화가 이 조건에서는 허용되지 않는 것으로 본다(추론). 협조적인 경우는 Automation 권한 프롬프트에 막혀 이번에 다시 측정하지 못했다.
- 미실측: 앱이 hidden일 때 `[NSApp unhide:nil]`을 부른 뒤 같은 블록에서 `makeKeyAndOrderFront:`까지 진행하는데, `-unhide:`가 그 시점에 동기로 창을 복원하는지 확인하지 않았다.
- 범위: 창을 보이는 경로(`mac_bring_frame_window_to_front_and_activate`의 자식·최상위 분기 두 곳)에 프로세스 활성화가 새로 들어간다. 수정 전에는 `mac_focus_frame`만 활성화했다. 자식 프레임은 툴팁과 달리 예외가 아니라 `no-focus-on-map` 없는 자식 프레임이 Emacs가 최전면이 아닐 때 뜨면 포커스를 가져간다(그 시점엔 대개 최전면이라 도달하지 않는다). `no-accept-focus`만 있고 `no-focus-on-map`은 없는 프레임도 같은 노출에 들어간다(창은 키가 되지 못하는데 프로세스 활성화만 일어난다). 트리와 설치된 패키지(corfu 포함)는 두 파라미터를 함께 주므로 도달하지 않는다. hidden 경로의 구조도 바뀐다: 수정 전에는 hidden이면 GUI 블록에 들어가지 않고 플래그만 세웠는데, 지금은 항상 블록에 들어가 정책을 먼저 Regular로 만든 뒤 hidden을 판정한다.
- 미수정: `mac_is_frame_window_frontmost`는 호출자가 없지만 upstream 함수라 diff를 줄이려고 남겼다. 명시적 hidden + Prohibited 상태에서 no-focus 프레임을 보이면 창은 `needsOrderFrontOnUnhide`로 미뤄지고 정책만 Regular가 되어 Dock 아이콘만 되살아난다(위 구조 변경의 결과. 두 상태가 동시에 성립하기 어렵다). 번들 밖 실행에서는 NS 포트와 달리 앱 아이콘을 세우지 않아 Dock 아이콘이 기본 아이콘이다.

### alpha 프레임 파라미터를 Mac 창을 만든 직후 적용한다
- 분류: 데몬 커밋이 main에 있는 조건에서만 main이다.
- 수정 방식: Mac 포트는 `Fx_create_frame`이 `alpha` 파라미터를 처리한 뒤에 창을 만들므로, 창을 만드는 함수 안이 적용 지점이다. 툴팁 프레임은 자기 경로에서 alpha를 적용하므로 여기서 제외한다.
- 범위: `mac_set_frame_alpha`는 highlight 프레임이 아니면 `alpha[1]`(비활성 값)을 쓰고 새 창은 그 시점에 highlight가 아니므로, 항상 비활성 값이 적용된다. 스칼라 alpha는 두 슬롯이 같아 warm-up에 영향이 없고, cons alpha는 포커스 전까지 비활성 값으로 뜬다(X 포트와 같다).

### 데몬 모드에서 GUI 프레임 생성을 지원한다
- 전제: GUI 프레임은 로그인된 Aqua 세션(예: 사용자 LaunchAgent)에서 띄운 데몬만 만들 수 있다. 시스템 LaunchDaemon이나 ssh 세션에서는 창 서버 세션이 없어 초기화를 건너뛰고 tty 프레임만 낸다.
- 의존: 활성화 커밋에는 패치 문맥과 런타임 양쪽으로 의존한다. 심볼을 호출하지는 않고, 이 커밋이 거는 Prohibited 정책을 되돌리는 코드가 활성화 커밋뿐이다. alpha 커밋에는 런타임(warm-up 투명도)으로만 의존한다.
- 범위: `mac-ae-select-frame-for-open`은 최소화 프레임을 쓸 수 있는 프레임으로 세지 않고, 완전히 보이는 프레임이 없으면 최소화 프레임 하나를 `make-frame-visible`로 되살린 뒤 선택한다(처음엔 `frame-visible-p`가 `icon`을 돌려주는 최소화 프레임도 골라 열린 버퍼가 화면에 나타나지 않았다. 검토로 발견해 고쳤고 테스트가 있다).
- 옵션: `mac-daemon-warm-up`(기본 t). warm-up 프레임에는 `no-focus-on-map`을 주지 않아 앱을 한 번 활성화하고 그 순간 포커스를 가져간다. 첫 활성화 비용도 미리 치르려는 선택이다. warm-up은 `frame-alpha-lower-limit`를 `let`으로 0에 묶는다. `make-frame` 안의 훅에도 보이고 함수 밖으로 새지 않는다.
- 유지 근거: `mac-ae-reopen-application`의 z-order 절은 Dock 클릭이 최전면 프레임을 되살리게 한다(폴백은 `frame-list` 순서를 따르므로 다른 프레임을 고를 수 있다. 실측). reopen 핸들러의 재작성은 비데몬 Emacs.app의 Dock 클릭 동작도 바꾼다(선택 프레임 유지 대신 z-order 최전면 프레임). `install_application_handler`(`[NSApp run]` 뒤)와 `mac_term_init`에서는 활성화 정책을 바꾸지 않는다. 그 시점에 바꾸면 warm-up 프레임 제거 뒤 Dock 타일이 고착된다(실측). `mac-daemon-hide-dock-icon`을 첫 idle로 미루는 것도 launch 등록이 정착한 뒤에 정책을 세우려는 같은 이유이고, 코드에는 `mac_term_init`에만 정책 변경을 그때까지 미뤄야 한다는 제약을 적었다.
- 범위: 마지막 Mac 프레임이 삭제될 때 터미널을 살려 두고 Dock 아이콘을 숨기는 것은 데몬 한정이 아니다. 조건이 디스플레이 참조 카운트와 `terminal->name`뿐이라 비-데몬 Emacs.app도 같은 경로를 지난다(`delete_terminal`은 남은 프레임을 지우기 전에 `terminal->name`을 비우므로 터미널 삭제 경로에서는 이 절이 돌지 않는다). suspend는 정책 전환만 하고 비트맵은 건드리지 않는다(처음엔 NS의 삭제 경로 코드를 그대로 가져와 `image_destroy_all_bitmaps`까지 불러 살아 있는 터미널의 비트맵 id를 무효화했다. 코드 검토로 발견해 고쳤다). `mac-application-state`의 `:hidden-p`도 `applicationHiddenExplicitly` 보정을 받는다(처음엔 생 `isHidden`이라 warm-up을 끈 데몬의 첫 reopen이 약 100ms 헛돌았다). 미니버퍼 중단 판정은 보이거나 최소화된 Mac 프레임만 호스트로 센다(처음엔 보이지 않는 프레임도 세어 미니버퍼가 닿을 수 없는 프레임에 갇힐 수 있었다. warm-up 프레임은 알파 0일 뿐 가시 상태라 이 판정에서는 호스트로 세어진다). `display-format-alist`의 "Mac" 엔트리는 pdmp에 실려 비-데몬 터미널 Emacs에도 남는다(터미널 Emacs를 쓰지 않아 무관).
- 범위: `-[EmacsMenu performKeyEquivalent:]`의 key window 부재 폴백에 `FRAME_MAC_P (SELECTED_FRAME ())` 가드를 더한다. 데몬의 초기 프레임은 Mac 프레임이 아니라 `output_data.mac`이 NULL이므로, 폴백이 그대로 `FRAME_MAC_WINDOW_OBJECT`를 읽으면 죽는다(warm-up 직후 Cmd 조합 입력으로 실측). 업스트림에는 비-Mac 선택 프레임으로 이 폴백에 닿는 경로가 없어 도달 조건을 이 커밋이 만든다.
- 범위: `display-format-alist`의 "Mac" 엔트리를 톱레벨로 옮겨 `window-system-for-display`가 emacsclient의 "Mac"을 해석하게 했고, `mac-setup-mouse-wheel`을 디스플레이 초기화에서 분리했다. `window-system-initialization`이 after-init-hook에 거는 함수 셋 중 데몬 경로는 `mac-process-deferred-apple-events`와 `mac-setup-mouse-wheel`을 직접 부르고 초기 GUI 프레임에 포커스를 주는 것은 부르지 않는다.
- 범위: 미니버퍼 중단은 single-keyboard 모드가 recursive-edit 스택을 이 터미널 하나에 가두는 것을 전제로 `top-level`로 돌아간다. 그러지 않으면 다음에 만든 프레임이 갇힌 recursive edit 안에서 열린다. 다른 Mac 프레임이 살아 있으면 미니버퍼는 `move_minibuffers_onto_frame`으로 옮겨져 중단이 필요 없다.
- 검증: Lisp 쪽 테스트는 픽스처가 프레임마다 종류와 가시성을 담아, 스텁이 프로덕션 술어를 실제로 부른다. `mac-daemon-hide-dock-icon`의 두 절과 warm-up 분기, 미니버퍼 중단의 두 가드(삭제된 프레임의 Mac 판정, 남은 프레임의 Mac 판정)는 각각 그것을 지우면 어느 테스트가 깨지는지 실측으로 확인했다.
- 미수정: IS_DAEMON 특례를 없앴으므로 창 시스템을 초기화하기 전에는 `mac-osa-script`와 `play-sound`가 NSApp 없는 GUI 경로를 거친다. `mac_within_app`이 블록을 실행하지 않아 ARC의 `__block` 결과가 nil로 남아 mac-osa-script는 `("OSA script error")`를 시그널하고 play-sound는 재생 시간만큼 CPU를 돈다(init에 그런 호출은 없다). warm-up 프레임이 `after-make-frame-functions` 실행 전에 시그널하면 정리되지 않는다(드묾). `emacs-startup-hook`은 `server-start`와 `daemon-initialized`보다 뒤에 돌므로 서버 기동 후 창 시스템 초기화 전 구간이 열려 있고 `emacs --daemon`은 창 시스템 초기화 전에 셸로 돌아오지만, 그 사이에 소켓을 읽는 지점이 없어 도달성은 낮다. `window-system-initialization`이 `x-open-connection` 성공 뒤(fontset 생성 등)에 시그널하면 `window-system-initialized` 속성이 붙지 않아 다음 `make-frame`이 `x-open-connection`을 다시 부르는데, `mac_term_init`이 "only handle one display" 에러를 깨끗이 내므로 결과는 양성이다(드묾). warm-up이 `select-frame`으로 바꾼 선택 프레임은 명시적으로 원복하지 않고 warm-up 프레임 삭제 시 `delete_frame`의 선택에 맡긴다.
- 미수정: `mac-daemon-hide-dock-icon`의 가드는 보이는 Mac 프레임만 세는데 실제 suspend 조건(C의 `dpyinfo->reference_count == 1`)은 가시성을 보지 않으므로, warm-up 프레임을 지울 때 보이지 않는 Mac 프레임이 살아 있으면 Dock 아이콘이 남는다. init에서는 `sunb--setup-frame`이 `make-frame` 안에서 가시화를 마치므로 첫 idle에 보이지 않는 프레임이 남는 경우가 드물다.
- 미수정: `mac_delete_terminal`의 업스트림 주석(마지막 프레임 삭제 때 불린다)은 이 커밋 뒤로 부정확하지만 diff를 줄이려고 고치지 않았다.

### macOS 데스크톱 알림을 지원한다
- 의존: 데몬 커밋이 만든 mac-win-tests.el을 고친다.
- 수정 방식: 알림 id는 세션마다 상위 비트를 난수로 잡고 하위 20비트를 순차 카운터로 쓴다. Notification Center에 이전 세션의 배너가 남아 있어도 id가 겹치지 않게 하려는 것이다. title과 body가 둘 다 비면 macOS가 배너를 그리지 않아 호출자에게 소리만 남으므로, 시스템이 빈 title에 이미 보여 주는 앱 이름(`Emacs`)을 title로 폴백한다. 인가 프롬프트는 판정이 아니라 응답 여부만 기억한다. 인가되지 않은 `-addNotificationRequest:`는 스스로 실패하고 그 완료 핸들러가 콜백을 폐기하므로, 판정을 따로 들고 있지 않아도 된다. 대기 큐에 같은 identifier를 다시 게시하면 큐에 있던 요청을 지우고 가장 새 게시로 넣는다. 큐가 상한을 넘으면 실패한 제출과 같이 취급해 가장 오래된 요청을 버리고 그 콜백을 폐기한다.
- 옵션: `mac-notifications-callback-limit`(기본 256). 아직 배달되지 않은 콜백을 몇 개까지 들고 있을지 정하고, 새 콜백을 넣은 뒤 항목 수가 이 값을 넘지 않도록 등록 일련번호가 가장 오래된 것부터 버린다. 0 이하이면 상한이 없다. 인가를 기다리는 요청을 담는 대기 큐의 상한 `MAC_PENDING_NOTIFICATION_LIMIT`는 사용자 옵션이 아니라 이 변수로 바꿀 수 없다.
- 유지 근거: 지금 도달하는 것은 Emacs.app 기동의 `setUpNotifications`(번들 밖 `src/emacs`에서는 bundleIdentifier가 nil이라 즉시 반환하고 `mac-notifications-notify`는 항상 에러를 낸다), title/body/urgency 전달, 인가 대기 큐(세션 첫 알림이 띄운 승인 창이 떠 있는 동안 들어온 요청이 순서대로 쌓인다), 알림마다 도는 `submitNotificationRequest:`와 그 완료 핸들러(실패 시 `discardNotificationRequests:`의 지연 블록까지. 콜백 테이블이 비어 있어 no-op), `willPresentNotification:`, 그리고 배너를 클릭하거나 닫을 때마다 불리는 `didReceiveNotificationResponse:`다(delegate와 `CustomDismissAction` 카테고리 등록만으로 돈다. 콜백이 없으면 `take_callback`이 nil을 돌려 `FUNCTIONP`에서 끝나지만, 그 전에 `mac_within_lisp_deferred_and_wake`로 Lisp 스레드를 깨우고 지연 큐에 append 한다. 이 append는 잠금 없이 돌지만 메인 큐 블록이라 사용 조건에서는 드레인과 겹치는 창이 열리지 않는다. 큐 잠금 커밋은 dev에 파킹했다(그 소절 참고)). `mac_within_lisp_deferred_and_wake`는 `mac_within_lisp_deferred_unless_popup`과 달리 팝업 중에도 동기 `mac_within_lisp`로 전환하지 않는다. plain `mac_within_gui` 블록 안의 호출자는 Lisp 스레드가 `mac_lisp_semaphore`만 기다려 inner Lisp 작업을 처리하지 않고, 메인 큐 블록의 호출자는 Lisp 스레드가 어느 대기 상태인지 알 수 없어 동기 전환이 안전하지 않다. 콜백(:on-action/:on-close)의 `FUNCTIONP` 이후, close, `[notification action]` 디스패치, 대기 큐 상한(`MAC_PENDING_NOTIFICATION_LIMIT` 256)과 콜백 상한(`mac-notifications-callback-limit` 256)을 넘는 경로는 호출자가 없다. 기준대로면 그 부분은 dev에 두어야 하지만, 사용 계획이 있어 쪼개지 않고 main에 통째로 둔다(결정). dev의 셀렉터 커밋은 이 커밋의 `mac_within_lisp_deferred_and_wake`에만 의존한다. 업스트림과 차이가 가장 크다. 지금 쓰는 기능(title/body/urgency)만이면 `mac-osa-script`의 `display notification`으로도 되지만, `:replaces-id` 치환·그룹화·interruptionLevel·계획된 콜백이 C를 정당화한다.
- 전제(SDK): `#if MAC_OS_X_VERSION_MAX_ALLOWED >= 120000`이 기능 전체를 감싼다(12.0이 필요한 것은 interruptionLevel뿐). configure의 `-weak_framework`는 SDK와 무관하게 붙는다(무해한 불일치).
- 관용 이탈: `mac_notifications_available_p`가 Lisp 스레드에서 `block_input`/`mac_within_gui` 없이 `NSBundle.mainBundle.bundleIdentifier`를 읽는다. 포트에서 유일한 지점이고 NSBundle은 스레드 안전이다.
- 표시: 소리는 `:sound`를 넘기지 않으므로 나지 않는다. Emacs가 최전면이 아닐 때는 `willPresentNotification:`이 아예 불리지 않고, init이 넘기는 `:urgency low`가 Passive로 매핑되어 화면 점등도 소리도 없이 배달된다.
- 전제: 번들 재서명은 build.sh가 맡는다(트리에는 번들을 서명하는 규칙이 없고, src/Makefile.in이 temacs와 bootstrap-emacs를 ad-hoc 서명할 뿐이다). 서명 없는 번들은 `applicationDidFinishLaunching:` 안의 `setUpNotifications`에서 예외가 나 알림 실패가 아니라 기동 불가일 것으로 본다(미실측).
- 완화: init의 호출이 `ignore-errors`로 감싸져 있어 창 시스템 초기화 전의 error는 message 폴백으로 떨어진다.
- 미수정: 인가 거부 시의 배치 폐기와 `addNotificationRequest:` 실패 완료 핸들러 두 곳은 콜백 폐기를 지연 블록으로 미루는데, 그 사이 같은 id로 다시 notify 하면 늦게 도는 폐기가 새 콜백을 지운다. 두 경우 모두 새 알림 역시 배달되지 않을 대상이라 실질 피해는 없다. 대기 큐 넘침의 콜백 폐기는 같은 `mac_within_gui` 안에서 드레인되어 notify가 돌아오기 전에 끝나므로 이 창을 열지 않는다.
- 검증: 콜백 상한의 "가장 오래된 것" 판정을 처음엔 초 단위 타임스탬프로 해서 동률이면 해시 순회 순서로 임의 항목이 버려졌다. 코드 검토로 발견해 고쳤고 실측은 없다. 테스트 하나가 지금 도달하지 않는 Lisp 디스패치만 덮고, action/close 분기는 C에 있어 덮이지 않으며, 실제로 도달하는 대기 큐는 수동 검증뿐이다(상한과 prune은 콜백을 넘길 때만 돌아 지금은 도달하지 않는다). `mac_notification_prune`은 일련번호가 fixnum 범위를 넘으면 최신으로 오판하지만, 비교 대상이 0에서 시작하는 등록 일련번호라 도달하지 않는다. `:sound`는 `+[UNNotificationSound soundNamed:]`가 번들/Library/Sounds에서 찾는 이름을 받으므로 시스템 사운드 이름이 그대로 울리는지는 미실측(넘기지 않는다).

### Mac에서 undecorated-round 프레임 파라미터를 지원한다
- 의존: 알림 커밋 뒤에서만 적용된다(순서 문단 참고). 심볼 의존은 없다.
- 수정 방식: homebrew-emacs-plus의 round-undecorated-frame 패치를 옮겼다. 창의 `movable`을 지운 것은 창 서버가 타이틀바 드래그 영역으로 잡는 맨 윗줄을 되찾는 방법이 그것뿐이라고 보았기 때문이다.
- 유지 근거: `updateWindowStyle`에서 내부 툴바 플래그를 `!shouldBeTitled || 라운드`로 대입하는 것(타이틀바 유무에 라운드를 OR)이 fullscreen 왕복에 필요하다(재구성 조건은 런타임 토글용이고 FullSizeContentView 조건은 방어적 중복이다). 최소화 버튼도 이 커밋이 숨긴다. `mac_bring_frame_window_to_front_and_activate`의 탭 가드는 main 창이 탭 금지면 새 창도 order-front 동안 금지로 두고(끝나면 새 창은 Automatic으로 돌아간다), main 창의 탭 모드를 upstream처럼 Automatic으로 되돌리는 대신 이전 값으로 복원해 라운드 창의 금지를 지우지 않는다(처음엔 되돌려서 라운드 아닌 최상위 프레임을 띄우면 라운드 main 창의 금지가 풀렸다. 코드 검토로 발견해 고쳤고 실측은 없다). `x-create-frame`은 nil이어도 파라미터를 저장하므로 모든 Mac 프레임의 파라미터 목록에 항목이 생긴다(`undecorated`와 같다). 탭 금지는 네이티브 탭 바가 되찾은 맨 윗줄 위에 그려지는 것을 막는다.
- 범위: 자식 프레임과 비네이티브 fullscreen 창은 borderless로 남는다(`shouldBeTitled`가 거짓). `updateWindowStyle`은 내부 툴바 플래그나 FullSizeContentView 마스크가 프레임과 어긋나면 창을 다시 만들어 런타임 토글을 덮는다.
- 손실: 라운드 프레임에서 Ctrl+Cmd 드래그는 창 이동에 쓰여 Lisp에 오지 않는다. 탭 그룹 거부가 없어 `mac-set-frame-tab-group-property`를 직접 부르면 라운드 프레임이 탭 그룹에 들어갈 수 있다(자동 탭 경로는 막혀 있다).
- 검증: 같은 문자 크기(40x10)의 대조 프레임과 비교해 라운드 프레임의 창 장식이 0px이었다(대조는 52px. 실측 2026-09-03).
- 미실측: `performWindowDragWithEvent:` 직후 `movable`을 되돌리는데 그 호출이 드래그를 동기로 끝내는지 확인하지 않았다.
- 미수정: `mac-transparent-titlebar`를 t에서 nil로 되돌리면 타이틀바가 첫 줄을 덮는다(그 경로는 쓰지 않는다). 네이티브 fullscreen에서도 `shouldBeTitled`가 참이라 창이 재구성되면 표준 버튼 3개가 숨겨지고 `movable = NO`가 걸린다(키보드 중심이라 무해). `setupWindow`의 라운드 후처리 블록이 `!FRAME_TOOLTIP_P` 밖에 있으나 툴팁이 이 파라미터를 갖는 경로가 없다.

### 명령 루프의 비지역 탈출에서 autorelease 풀을 비운다
- 범위: command loop에 들어가기 전(loadup, init, 데몬 startup)의 `funcall_subr` 고아 풀은 덮이지 않는다. 1회성이고 유한하다. `make-thread`로 만든 Lisp 스레드도 덮이지 않는다: `run_thread`는 `HAVE_NS`에서만 스레드 기저 풀을 잡고 `HAVE_MACGUI` 대응이 없어, 그 스레드에서 시그널이 날 때마다 `funcall_subr` 고아 풀이 스레드 종료까지 누적된다(`make-thread`를 쓰기 시작할 때 본다).
- 부수효과: 이터레이션마다 `unbind_to`가 돌아 본문이 specpdl에 남긴 항목도 되감긴다. 본문은 균형이 맞아 실동작 차이는 없다. subr 호출을 감싸는 안쪽 루프는 `@autoreleasepool` 블록 형식을 그대로 쓴다. 그 고아 풀은 명령 루프의 풀이 pop 될 때 함께 비워진다.
- 미수정 없음: push와 `record_unwind_protect_ptr` 사이에 시그널 지점이 없고, `record_unwind_protect_ptr`는 항목을 먼저 쓴 뒤 `grow_specpdl`을 부르며 `grow_specpdl`은 포인터를 먼저 올리므로 specpdl 확장이 `memory_full`을 내도 풀은 되감긴다.

### Mac fullscreen 검사를 GUI 스레드 밖으로 미룬다
- 증상: `mac_handle_visibility_change`는 GUI 스레드의 AppKit 콜백에서도 도는데, 거기서 `mac_check_fullscreen`이 `mac_change_frame_window_wm_state`를 거쳐 GUI 스레드를 기다리면 그 대기가 끝나지 않는다.
- 유지 근거: 지연 블록이 raw struct frame *를 포획하는데 이 포트의 기존 관용구(`frame.h`의 `SET_FRAME_ICONIFIED`가 GC 미보호 `Lisp_Object`를 포획)와 같아 두지 않는다. 재검사가 걸러 내지 못하는 것은 GC가 frame 벡터를 회수한 경우뿐이고, 그것은 `delete_frame` 주석대로 한참 뒤다.
- 범위: 가시성 재검사는 GUI 스레드(지연) 경로에만 건다. Lisp 스레드에서는 `f->visible`이 함수 끝에서야 갱신되므로 인라인 경로에서도 재검사하면 프레임 생성 시(`Fx_create_frame`이 fullscreen을 가시화보다 먼저 처리) 검사가 한 라운드 밀린다(처음엔 그랬다. 코드 검토로 발견해 고쳤다. init은 생성 시 fullscreen을 주지 않아 실측은 없다). `mac_check_fullscreen`의 다른 호출처 `mac_fullscreen_hook`은 Lisp 스레드 전용이라 수정 대상이 아니다.
- 검증: 정지 재현 때 메인 스레드 샘플이 전부 `mac_within_gui_and_here`의 `dispatch_semaphore_wait`에 있었다. `--enable-checking` 빌드였다면 두 헬퍼의 `eassert (!pthread_main_np ())`로 정지가 아니라 abort였을 것이다. 최소화 -> 최소화된 채 `fullscreen` 파라미터 변경 -> 되살리기를 5회 돌려 모두 정지하지 않았고, 되살린 뒤 `emacsclient --eval`이 매번 제한 시간 안에 돌아왔다(실측 2026-09-03. 되살리기는 외부 프로세스의 `rapp` Apple Event로 4회, `make-frame-visible`로 1회 했다). 이 커밋이 다루는 경로를 지났다는 근거는 최소화 중에는 fullscreen이 적용되지 않다가 되살리는 순간 적용된 것이다(가시성 변경 콜백에서 검사가 돌았다).
- 한계: 이 빌드에서 커밋을 빼고 정지를 재현하는 대조는 하지 않았으므로, 커밋이 없으면 정지한다는 쪽은 위 실측이 아니라 과거 실측 기록에 의존한다. `make-frame-visible`로 되살린 회차는 2초 뒤에도 아직 `icon`이었고 몇 초 뒤 복원이 끝났는데, 정지가 아니라 deminiaturize의 비동기 완료로 본다(추론). dev의 최소화 커밋이 main에 없는 상태와 일관된다.
- 미실측: 지연 블록이 `mac_check_fullscreen`을 거쳐 `mac_within_gui`를 부르므로, inner Lisp 왕복 중에 드레인되면 `mac_within_lisp_deferred_and_wake` 주석의 제약(지연 블록은 `mac_within_gui`를 부르면 안 된다)을 어긴다. 어기면 이렇게 된다: `mac_within_gui_allowing_inner_lisp`의 루프가 부르는 `mac_within_gui (nil)`이 반환 전에 지연 큐를 드레인하는데, 그때 지연 블록이 `mac_check_fullscreen` -> `mac_change_frame_window_wm_state`로 `mac_within_gui_allowing_inner_lisp`를 다시 부르면, Lisp 스레드의 `dispatch_semaphore_wait (mac_lisp_semaphore)`가 자기 GUI 블록의 완료 신호가 아니라 밖에서 진행 중이던 블록의 완료 신호를 먹고 먼저 깨어난다. 즉 GUI 블록이 실행되기 전에 호출이 반환되고, 그 뒤 GUI 블록이 Lisp 스레드와 겹쳐 돈다. 그 드레인 창을 여는 되부름 경로 5곳(큐 잠금 소절 참고)은 사용 조건에서 밟지 않는다(Emacs 창 위로 끌지 않는 한). 이벤트를 만들지 않는 viewDidHide/viewDidUnhide 경로에서는 깨우기가 없어 재검사 실행이 늦을 수 있다.

### 배율 1 프레임의 Mac 고해상도 이미지 처리를 고친다
- 수정 방식: 논리 크기를 프레임 배율과 무관하게 절반으로 두는 근거는, DPI로 2배라고 판정한 것이 밀도가 2배인 에셋 하나라는 점이다. `target_backing_scale`은 그 에셋을 어느 밀도로 래스터화할지 고르는 데 쓰이면서, `search_image_cache`의 일치 조건이기도 하다: 캐시 항목의 값이 0이거나 조회하는 프레임의 배율과 같아야 일치로 본다. 그래서 상수 2가 아니라 프레임의 배율을 기록하는 것이 캐시 미스를 없앤다.
- 유지 근거: DPI 판정이 사용 조건의 스크린샷 PNG로 도달한다.
- 범위: 이 빌드는 PNG/JPEG/GIF/TIFF를 전부 ImageIO로 처리한다(`HAVE_PNG`/`HAVE_JPEG`/`HAVE_GIF`/`HAVE_TIFF` 없음, `HAVE_NATIVE_IMAGE_API`). WebP는 libwebp로, SVG는 librsvg로 가서 DPI 판정을 거치지 않는다. 따라서 DPI 판정의 도달 대상은 ImageIO로 가는 PNG/JPEG/GIF/TIFF/HEIC이고, Retina 화면의 `screencapture` PNG가 144 DPI를 기록하는 것이 대표 사례다(근거는 사용 조건의 "스크린샷 PNG를 본다"이고 "WebP를 본다"는 아니다).
- 증상: `lookup_image`가 매번 캐시 미스를 내 재디코드하고 캐시가 자란다(미스 때 옛 항목을 해제하지 않는다). `drawRect:`마다 `SET_FRAME_GARBAGED`가 걸리는 경로도 있으나 자기 지속 루프는 아니다: 기본 경로는 `updateLayer`가 캐시된 backing을 내보내고 `drawRect:`는 backing이 없을 때만 불리므로 backing 재생성마다 1회다.
- 검증: test/manual/mac-image-dpi-tests.el은 `--enable-checking` 빌드에서만 실행된다(build.sh의 configure에는 없으므로 별도 빌드가 필요하다). `still-size` 테스트는 수정 전에도 통과하는 회귀 가드이고 `cache-hit`가 DPI 판정 수정을 검증한다. 테스트 스펙에 `:scale 1`을 준 것은 `create-image`가 붙이는 `:scale default`와 `image-scaling-factor`의 기본값 `auto` 때문에 기대 크기가 프레임 폰트 폭을 타기 때문이다. `image-cache-size`는 모든 프레임의 합계라 GUI 세션에서는 `cache-hit`가 흔들릴 수 있다. 테스트용 DEFUN은 기록값만 바꾸고 창 배율과 재동기화하지 않으므로(같은 트릭을 쓰는 툴바 코드와 다르다) 테스트가 `unwind-protect`로 원복한다.

### 이미지의 모든 배율 사본을 flush 한다
- 도달 경로: 두 프레임을 두 화면에 두는 경우만이 아니다. `windowDidChangeBackingProperties:`가 프레임 배율만 갱신하고 이미지 캐시는 건드리지 않으므로, 프레임 하나를 Retina에서 비-Retina로 옮긴 뒤 flush 하면 옛 배율 사본이 남고 되돌아오면 옛 이미지가 보인다(`image-cache-eviction-delay` 300초 안).
- 범위: 이 커밋이 해제 노출 범위를 배율을 안 따지는 공유 항목에서 배율별 사본까지 넓힌다. `ignore_colors`여도 `:data`/`data_2x` 비교는 남지만 flush는 캐시된 것과 같은 spec을 넘기므로 도달하지 않는다.
- 검증: test/manual/mac-image-dpi-tests.el의 flush 테스트가 두 배율 사본을 한 번에 지우는지 본다. `--enable-checking` 빌드의 GUI 세션에서만 돌고, `cache-hit`와 같이 `image-cache-size` 합계를 보므로 흔들릴 수 있다.
- 미수정: `uncache_image`는 `image-scaling-factor`가 `auto`면 `FRAME_COLUMN_WIDTH`로 계산한 배율도 비교하므로 두 프레임의 폰트 폭이 다르면 반대쪽 사본이 남는다. 인자로 받은 프레임만 garbage로 표시하므로, 캐시를 공유하는 다른 프레임의 current matrix에는 해제된 image id가 남고, 그 프레임이 그 행을 다시 그리면 `IMAGE_FROM_ID`가 NULL을 돌려줘 역참조로 죽는다(`eassert`는 이 빌드에서 no-op). 업스트림에도 있는 구조이고(upstream도 face 색이 다른 다른 프레임의 사본을 해제하면서 그 프레임을 garbage 처리하지 않는다), 실제 호출자(org, image-mode)가 flush 직후 버퍼를 고치므로 같은 버퍼를 보이는 프레임은 같은 주기에 재표시되고, 반대쪽 프레임이 다른 버퍼로 같은 spec을 공유할 때만 남는다. 노출만으로도 다시 그려질 수 있다: `viewDidChangeBackingProperties`가 backing을 버리면 `updateLayer`가 `drawRect:`로 떨어져 `expose_frame`이 current matrix를 그대로 다시 그리고, 그 트리거는 창의 배율 변경 즉 화면 사이 프레임 이동 자체다. 남는 방어선은 위의 "반대쪽 프레임이 다른 버퍼로 같은 spec을 공유할 때만"이라는 조건뿐이다. 판단을 뒤집을 때는 `image-flush`에 FRAME t를 주면 모든 프레임이 garbage로 표시된다.

### self-contained Mac 설치에서 DESTDIR을 존중한다
- 수정 방식: `ELN_DESTDIR`에 DESTDIR을 붙이는 대신 설치 경로 전용 변수 `INSTALL_ELN_DESTDIR`을 새로 두었다. `ELN_DESTDIR` 자체는 빌드 시 하위 make에도 넘어가므로 거기에는 붙이지 않았다.
- 범위: uninstall 규칙도 같은 변수를 따르므로 `make DESTDIR=x uninstall`은 설치된 것이 아니라 staging의 네이티브 Lisp 파일을 지운다. 다시 쓴 두 명령은 업스트림과 달리 경로를 인용한다.

### local
- 전제: `staged_app`의 `/Applications`가 configure의 `--enable-mac-app=yes`와 암묵적으로 결합돼 있어 한쪽만 바꾸면 `apply_liquid_glass_icon`의 대체 아이콘 존재 검사가 없는 경로에서 실패해 `set -e`로 중단된다. `rm -rf .../Resources/lib/systemd`는 configure.ac가 self-contained 분기에서 비운 `INSTALL_ARCH_INDEP_EXTRA`를 뒤에서 `install-etc`로 무조건 덮어쓰는 upstream 결함 때문에 필요하다.
- 미수정: mac/Makefile.in의 srcdir->builddir 복사 목록에 새로 넣은 파일 3개(Assets.car, EmacsLG1-Default.icns, EmacsLG1-COPYRIGHT.txt)가 없어 VPATH 빌드에서는 대체 아이콘이 번들에 없다. `apply_liquid_glass_icon`이 대체 아이콘 존재를 확인하고 없으면 실패하므로 아이콘 없는 번들이 조용히 만들어지지는 않는다. 인트리 빌드는 tar로 통째 복사하므로 사용 조건에서는 도달하지 않는다. `Contents/Resources/lib`가 빈 디렉터리로 남는다.

## dev (17개, 스택 아래부터)

| 커밋 제목 | 파킹 이유 |
|---|---|
| null Apple event 레코드 필드의 키를 보존한다 | AE 파라미터에 typeNull 항목이 있어야 도달. 보내는 쪽은 `(TYPE . STRING)` 아닌 값을 넣을 때만 만들고(정상 브리지는 넣지 않음), 수신 쪽 후보인 HS 답신은 지금 쓰지 않음 |
| Apple event 파라미터를 키로 교체한다 | 같은 키를 한 이벤트에 두 번 설정할 때만 발생. 트리 안에서 도달하지만 무해(소절 참고) |
| atimer 시그널 마스크를 비지역 탈출에서 복원한다 | 현재 timer 콜백은 throw 하지 않음(트리거 없음). 막히면 다음 C-g까지 모든 atimer가 정지 |
| Darwin에서 one-shot atimer 재활용을 고친다 | 재활용은 hourglass 경로로 도달하지만 두 콜백이 timer를 다시 역참조하지 않아 결과가 양성 |
| Mac AppKit 셀렉터 처리를 올바른 스레드에서 한다 | 사용 조건이 `mac_within_lisp` 되부름 경로를 밟지 않아 경합 창이 열리지 않음(Emacs 창 위로 끌지 않는다는 전제 포함. 큐 잠금 소절 참고). 되살릴 때 위험은 경합이 아니라 스냅샷 기반 인식으로의 동작 변화 |
| trylock 헬퍼에서 current_thread를 잠금 아래에서 검사한다 | Lisp 스레드 2개 이상에서만 도달 |
| Mac의 characterIndexForPoint에서 글리프 행렬 접근을 가드한다 | 잠금 가드는 단일 스레드에서 no-op(항상 활성인 부분은 소절 참고) |
| Mac의 markedRange에서 버퍼 접근을 가드한다 | 단일 스레드에서 완전한 no-op |
| Mac의 최소화 프레임 가시성 처리를 고친다 | 반복 ICONIFY_EVENT는 무해하고 낭비만 남음 |
| Org 수식 이미지의 두 배율을 모두 보존한다 | LaTeX 미설치라 도달 불가 |
| play-sound-internal의 비지역 탈출에서 CFTypeRef 누수를 고친다 | play-sound 미사용 |
| Mac 파일 이름 강제 변환의 미초기화 결과 디스크립터를 고친다 | CoreFoundation이 거부하는 바이트열(유효하지 않은 UTF-8)을 파일 URL로 보내는 앱이 있어야 도달(결과는 소절 참고) |
| mac-reverse-video-cursor 옵션을 추가한다 | cursor-type을 bar로 바꿔 쓰지 않게 됨(남기는 결정과 세부는 소절 참고) |
| Mac 폰트 목록의 Core Foundation 객체 수명을 고친다 | CF 규칙 위반은 맞지만 현재 CoreText 구현에서는 발현하지 않음(실측) |
| Mac의 지연 Lisp 큐에 잠금을 건다 | 겹침은 `mac_within_lisp` 되부름 뒤에만 생기는데 사용 조건이 그 경로를 밟지 않음. `make-thread`를 쓰면 창이 넓어지므로 그때 스레드 묶음과 함께 되살림 |
| macOS의 pty 읽기 처리량을 높인다 | 실측으로 실제 볼륨(256 KiB)에서 이득이 0.5 ms뿐이고, 큰 이득이 나는 경로는 ghostel 네이티브 pty 모듈이 우회함. 필터가 싸면 오히려 손해(소절 참고) |
| 배율 1 프레임에서 @2x 형제 파일을 읽지 않는다 | `@2x` 형제 파일이 있어야 도달하는데 트리에도 설치된 패키지에도 없음 |

잠금 가드 3개는 `mac_select`의 `thread_may_switch_p`(Lisp 스레드 2개 이상)일 때만 활성화된다.
단일 스레드에서 GUI 스레드와 Lisp 스레드가 겹쳐 도는 구간은 GUI 블록이 `mac_within_lisp`로 Lisp를 되부른 뒤뿐이고(큐 잠금 소절 참고), 사용 조건이 그 되부름 경로를 밟지 않는 한(가장 밟기 쉬운 것은 Emacs 창 위로의 드래그. 큐 잠금 소절 참고) 셀렉터 커밋이 막으려는 keymap 경합도 실제로 일어나지 않는다.
스레드 묶음은 셀렉터 -> trylock -> characterIndexForPoint -> markedRange 순서로 되살리고, 큐 잠금도 그때 함께 가져간다.
`make-thread`를 실제로 쓰기 시작할 때 같은 부류의 미수정 12곳과 함께 검토한다.
IME의 쓰기 경로(insertText:, setMarkedText:)와 `observeValueForKeyPath:`(GUI 스레드에서 Lisp 객체를 만들어 storeEvent, `[application-kvo effectiveAppearance]` 기본 바인딩으로 상시 도달)는 어느 커밋도 가드하지 않고, `firstRectForCharacterRange:`에는 잠금 가드가 있는데 inhibit-quit 조기 반환이 없다. 단일 스레드에서는 위 이유로 경합이 아니므로 그때 함께 본다.
dev 안에서 `src/macappkit.m`을 고치는 다섯 커밋(큐 잠금 포함), `src/macterm.c`를 고치는 두 커밋, `src/mac.c`를 고치는 두 커밋(AE null 필드, 파일 이름 강제 변환)은 hunk가 겹치지 않아 체리픽 순서에 파일 제약이 없다.
pty 커밋은 `src/sysdep.c` 단독이고 그 파일을 건드리는 커밋이 dev에도 main에도 없어 아무 제약이 없다.
atimer 두 커밋은 `src/atimer.c` 단독이고 hunk가 50줄쯤 떨어져 있어 제약이 없지만(순서를 바꿔 적용해도 결과가 바이트 동일하다. 실측), 재활용 쪽이 마스크가 막힌 구간 안에 새 unwind 등록 지점을 만들므로 마스크를 아래에 두었다. 마스크만 단독으로 되살려도 되지만, 재활용을 되살릴 때는 마스크도 함께 가져간다(재활용만 가져가면 그 새 등록 지점에서 마스크가 막힌 채 남는 경로가 생긴다).
Apple event 묶음 중 파일 이름 강제 변환 커밋만 묶음에서 떨어져 있으나, dev는 리베이스하지 않으므로 인접 배치 원칙을 적용하지 않는다.
dev 커밋은 전부 upstream에 단독 strict apply 되고, main 위 3-way 체리픽은 최소화 커밋만 충돌한다(strict apply는 최소화와 큐 잠금이 실패한다. 실측). 최소화 커밋은 활성화 커밋이 고친 같은 줄 세 곳을 건드리므로 main 위에서는 충돌한다: `mac_bring_frame_window_to_front_and_activate`의 자식 분기(main 쪽은 `mac_ensure_app_activated ()`가 든 브레이스 블록이라 그 블록에 `order_front_p` 조건을 씌운다), 같은 함수의 `makeKeyAndOrderFront:`/`orderFront:` 블록(main 블록 전체를 `if (order_front_p)`로 감싼다), 호출처 `mac_show_frame_window`(툴팁 조건과 `!deminiaturizing_p` 인자를 합친다). 그 상태로 -Werror 빌드를 확인했다.

### null Apple event 레코드 필드의 키를 보존한다
- 도달 경로: 들어오는 org-protocol GURL과 Finder odoc, 그리고 `mac-send-apple-event`가 보낸 이벤트를 되돌리는 쪽이다. 들어오는 이벤트의 attribute는 keyword가 `ae_attr_table`에서 오므로 결함이 없지만, 파라미터는 결함 분기를 그대로 지나므로 수신 이벤트도 typeNull 파라미터가 있으면 도달한다. 실제 후보는 HmSp/EXEC의 답신(`callback` 비-nil 호출에서만 도착)인데 답신에 typeNull 파라미터가 실리는지는 미실측이고, 지금 init은 sunb-hammerspoon을 require 하지 않으며 기본 호출은 답신 없는 kAENoReply다. 실리면 sunb-hammerspoon.el의 TYPE 인자를 준 `mac-ae-parameter` 호출이 `wrong-type-argument`를 낸다. 보내는 쪽은 파라미터 값이 올바른 `(TYPE . STRING)`이 아니면 typeNull로 들어가므로 Hammerspoon 브리지 쪽 실수로 결정적으로 도달하지만, 결과는 크래시가 아니다. typeNull 필드가 가장 먼저 처리되는 최상위 인덱스 항목이면 쓰레기 4바이트 키가 붙을 뿐 `assoc`이 찾지 않아 수신 이벤트에서는 파라미터가 조용히 사라지고(보내는 쪽 반환값은 `mac-send-apple-event`가 원본 키를 다시 채운다), 그보다 앞 인덱스면 직전에 처리한 항목의 키를 물려받은 가짜 항목이 진짜 항목보다 앞에 놓여 `assoc`을 가로채 TYPE 인자를 준 `mac-ae-parameter`가 `wrong-type-argument`를 낸다. 파라미터가 하나뿐인 HmSp 사용에서는 항상 앞의 경우다. `mac-ae-set-parameter`에 `(TYPE . STRING)`만 넘기는 정상 사용에서는 typeNull 필드가 생기지 않는다(sunb-hammerspoon.el은 호출마다 새 이벤트를 만들고 `("utf8" . STRING)`을 한 번 설정한다).
- 수정 방식: keyword는 같은 switch가 이미 쓰는 `AEGetNthDesc`로 얻는다(처음엔 `AEGetNthPtr`에 `dataPtr` NULL, 크기 0을 넘겼는데 SDK 헤더가 그 인자를 nullable로 표시하지 않아 보장 밖이었다. 코드 검토로 발견해 고쳤다). 실패하면 필드가 통째로 빠진다(upstream은 쓰레기 키로라도 남겼다).

### Apple event 파라미터를 키로 교체한다
- 증상: 전송되는 것은 새 값이 아니라 옛 값이고, Lisp 쪽 `mac-ae-parameter`는 `assoc` 첫 매치라 새 값을 본다(비대칭). 같은 이벤트 객체에 같은 키를 두 번 설정할 때만 발현한다. 트리 안에서는 `mac-send-apple-event`의 동기 분기가 같은 이벤트에 `'callback`을 두 번 설정하지만(throw 람다와 unwind의 `'ignore`), `callback`은 `ae_attr_table`에 없는 심볼이고 4문자 문자열도 아니라 C 쪽 두 루프를 모두 통과하지 못하고 그 이벤트는 재전송되지 않아 무해하다. sunb-hammerspoon.el은 호출마다 새 이벤트를 만들어 유해 경로에 도달하지 않는다. 브리지가 이벤트를 캐시해 재사용하기 시작하면 main으로 옮긴다.
- 수정 방식: `assoc-delete-all`은 alist spine을 파괴적으로 고친다(docstring의 side effect 서술과 부합. spine을 공유하는 alias는 트리에 없다). 수정 전에는 반복 설정마다 alist가 자랐다. 심볼 키 attribute도 같은 결함이 있었다. `create_apple_event_from_lisp`의 앞쪽 attribute 루프도 마지막에 쓴 값이 이기는데, `assoc-delete-all`이 그쪽의 옛 항목도 지운다.
- 우회: 이벤트를 새로 만들어 키를 한 번만 설정한다.
- 되살릴 때: 순수 Lisp이라 테스트가 쉽지만 그 파일(mac-win-tests.el)은 main의 데몬 커밋이 만든 것이므로, main으로 체리픽할 때 함께 넣는다.

### atimer 시그널 마스크를 비지역 탈출에서 복원한다
- 도달 경로: 현재 timer 콜백(hourglass, with-delayed-message, poll_for_input)은 throw 하지 않는다. macOS 빌드는 `HAVE_SETITIMER`만 있어(timerfd/timer_settime 없음) atimer가 SIGALRM 전용이므로, 마스크가 막힌 채 남으면 다음 C-g까지 hourglass·delayed-message·`mac_handle_alarm_signal`이 전부 정지한다. `handle_interrupt`와 read_char의 quit 착지점이 quit마다 마스크를 통째로 비우고, GUI의 C-g도 `kbd_buffer_store_buffered_event`가 `handle_interrupt (0)`을 부르므로 데몬에 tty가 없어도 풀린다.
- 설계: 마스크를 저장하는 대신 `block_atimers`가 막을 두 신호 중 원래 안 막혀 있던 것만 unwind 인자로 실어 `SIG_UNBLOCK` 한다. 힙이 필요 없고, 등록이 블록보다 앞이라 specpdl 확장에 실패해도 마스크가 막힌 채 남지 않으며, 중첩 호출의 unwind는 저절로 no-op가 되고, quit 경로에서 read_char가 일부러 비운 마스크도 되돌리지 않는다. 다른 시그널(SIGCHLD 등)의 변경도 되돌리지 않는다(upstream의 `SIG_SETMASK`는 되돌렸다). 정적 저장소를 쓰지 않아 스레드 사이에 공유되는 것이 없다.
- 부수효과: 정상 경로에서도 `unbind_to`가 돌아 콜백이 specpdl에 남긴 것이 여기서 되감긴다.
- 검증: 마스크 로직만 떼어 중첩·최외곽 복구·quit 뒤 비운 상태 유지·콜백의 마스크 변경 보존 네 가지를 실행해 확인했다. Darwin과 비-Darwin 양쪽 -Werror 컴파일도 확인했다.
- 비용: 플랫폼 무관한 약 50줄(주석 제외 약 24줄)이다. `do_pending_atimers`는 핫패스(신호가 배달된 뒤 첫 `unblock_input` 0-레벨 복귀마다 돈다. `pending_signals` 게이트)인데 `pthread_sigmask` 호출이 2회에서 3회로 는다. 등록을 블록보다 앞에 두는 설계상 조회 1회가 불가피하고, 조회한 마스크 재사용으로 아끼는 것은 복사 한 번뿐이다.
- 미수정: unwind가 SIGINT를 `SIG_UNBLOCK` 하는 순간 대기 중이던 SIGINT가 배달되면 `handle_interrupt`가 `quit_throw_to_read_char`로 longjmp 할 수 있다(`waiting_for_input && !echoing`일 때만). 착지점 read_char가 곧바로 `unbind_to`를 하므로 남은 unwind는 건너뛰어지지 않고 지연될 뿐이고, 새로 노출되는 것은 진행 중이던 `unwind_to_catch`가 중단되어 원래 목표 `catch`가 값을 못 받는 것이다(quit로 인한 throw면 마스크가 이미 비어 있어 no-op. 콜백이 error로 빠질 때만 새 노출이고 사용자가 C-g를 눌렀다는 뜻이라 실질 위험은 낮다). "콜백은 throw 하지 않는다"는 `memory_full`을 제외한 서술이다.

### Darwin에서 one-shot atimer 재활용을 고친다
- 도달 경로: one-shot atimer는 hourglass와 with-delayed-message로 상시 발동한다. 수정 전에는 콜백이 도는 내내 timer가 free 리스트에 있어, 콜백이 도달하는 어느 코드에서든 `start_atimer`가 불리면 재활용된다. 지금 도달하지 않는 이유는 두 콜백이 첫 문장 이후로 timer를 역참조하지 않기 때문이다.
- 수정 방식: unwind에서 free 리스트로 옮길 때 `block_atimers`로 감싼다(C-g 경로에서는 read_char가 `unbind_to` 직전에 마스크를 비우므로 SIGALRM이 열린 채 unwind가 돈다. `handle_alarm_signal`이 리스트를 만지지 않아 오늘은 무해하지만 upstream에서 free 리스트로 반납하는 두 곳은 항상 막힌 구간 안이었다). 이터레이션마다 `unbind_to`가 돌아 연속 타이머 콜백이 specpdl에 남긴 것도 되감긴다(부수효과). 연속 타이머는 upstream이 콜백 전에 재스케줄하므로 손대지 않는다.
- 미수정: `funcall-with-delayed-message`의 `client_data`는 그 함수의 스택 struct 주소이고 `with_delayed_message_cancel`은 `xfree`를 부르지 않으므로, 재활용으로 인한 누수나 이중 free는 이 구현에 없다. 남은 것은 취소 쪽이다. 콜백 `with_delayed_message_display`가 `data->timer`를 NULL로 세우는 것은 `message3` 뒤이므로, 콜백이 `message3`에서 non-local exit 하면 그 필드가 남아 `with_delayed_message_cancel`이 `cancel_atimer`를 부른다(트리의 콜백이 빠져나가는 경로는 `memory_full`뿐이라는 전제는 마스크 소절과 같다). unwind는 깊은 쪽부터 도므로 이 커밋이 넣은 `free_atimer_on_unwind`가 struct를 free 리스트로 보낸 뒤에 그 `cancel_atimer`가 돌고, `cancel_atimer`는 `atimers`와 `stopped_atimers`에서만 찾아 없으면 아무것도 하지 않으므로 no-op다(`eassert`는 이 빌드에서 no-op). 그 두 unwind 사이에 도는 다른 unwind가 `start_atimer`로 struct를 재활용하면 남의 타이머를 취소하지만, 그런 unwind가 있는지는 미실측이다. 이 커밋이 닫는 것은 콜백이 도는 동안의 재활용 창까지다. 비-Darwin에서는 `t->fn (t)`가 free 리스트 반납보다 앞이라 콜백의 non-local exit로 struct가 영구 누수하는 upstream 결함이 그대로다(이 커밋은 Darwin 분기만 고친다).
- 비용: Darwin 분기 30여 줄이라 머지 비용이 있다.

### Mac AppKit 셀렉터 처리를 올바른 스레드에서 한다
- 의존: 알림 커밋이 만든 mac_within_lisp_deferred_and_wake를 쓰므로 그 위에서만 빌드된다(dev 단독은 3 errors. 실측). dev에서 변경량이 가장 크다.
- 되살릴 때: 단일 스레드에서도 셀렉터 인식이 스냅샷 기반이 된다. mac-win.el이 기본으로 거는 `[action]` 16개와 `[service perform]` 4개가 전부 새 경로를 타므로 검증 대상이 넓다. 스냅샷은 `mac_read_socket`에서 0.1초 하한으로 갱신되므로 입력을 읽지 않는 Lisp 루프 안에서는 갱신이 오지 않고, 첫 갱신 전에는 셀렉터를 전혀 인식하지 않는다(새로 정의한 `[action]` 바인딩은 다음 스냅샷까지 `mac-send-action`이 실패한다). mac-action-key-paths 값과 sender의 프레임은 GUI 스레드에서 전송 시점에 스냅샷을 찍어 지연 블록에 넘기며(지연 블록 안에서는 `mac_within_gui`를 부를 수 없다. 이유는 `mac_within_lisp_deferred_and_wake`의 주석에 있다), Foundation 값 객체가 아닌 것(NSFont 등)은 버린다(기본 key path 3개는 전부 통과한다). 스냅샷이 `map_keymap`이라 upstream(`noinherit`)과 달리 `[action]` 서브맵의 부모 키맵까지 인식하고, 자식이 nil로 가린 바인딩도 부모 값이 있으면 인식한다.
- 되살릴 때(그 밖의 동작 변화): 서비스 호출은 항상 지연이 되고, pasteboard 복사 결과만 AppKit에 보고하므로 그 뒤의 이벤트 저장 실패는 보고되지 않는다(결과를 반환하는 것은 `readSelectionFromPasteboard:`뿐이다). 액션 이벤트는 지연 큐 드레인 시점에 저장되므로 `mac_read_socket` 반환 count에 기여하지 않는다(소비자는 `readable_events`를 보므로 무해). 이벤트 구성도 드레인 시점이라 액션·서비스 이벤트의 프레임(`mac_event_frame`)과 서비스 이벤트의 키맵 조회가 AppKit 콜백 시점이 아니라 드레인 시점의 Lisp 스레드 기준이 되고, 같은 `mac_read_socket` 라운드에서 먼저 처리된 포커스 변경이 있으면 이벤트가 새 포커스 프레임에 귀속된다. `validRequestorForSendType:`도 스냅샷을 보므로 선택 소유권과 컨버터 목록의 변화가 최대 0.1초+ 늦게 반영되고 그 사이 서비스 메뉴 항목이 비활성일 수 있다. 스냅샷 재구축은 0.1초마다 서브맵 2개와 `Vselection_converter_alist`를 도는 상시 비용이고, 같은 순회를 `update_services_menu_types`(메뉴바 활성화 시에만, Lisp 스레드에서 호출)도 한다. Emacs가 PRIMARY를 소유 중이면(`select-active-regions` 기본 t라 리전을 한 번 잡으면 상시) 재구축의 `Fmac_selection_owner_p`가 매 라운드 `[NSPasteboard changeCount]` IPC를 낸다. GUI 스레드는 스냅샷의 key path 목록으로 값을 모으고 Lisp 스레드는 현재 `mac-action-key-paths` 속성을 다시 읽으므로, 스냅샷 갱신 전에 속성이 바뀌면 새 key path는 조용히 빠진다.
- 미수정: 지연 블록이 `Lisp_Object frame`을 GC가 보지 못하는 형태로 포획한다(같은 호출 끝에서 드레인되지 않는 메뉴 트래킹 중 액션에서만 창이 열린다. main의 fullscreen 커밋과 같은 부류다). `valuesRef`는 지연 블록이 끝내 실행되지 않으면 샌다(specpdl 확장 실패 시에는 등록한 unwind가 되감겨 해제된다). 재구축이 `mac_read_socket`의 `block_input` 안에서 `Fget (Vmac_service_selection, ...)`을 부르므로 `mac-service-selection`을 심볼 아닌 값으로 두면 `CHECK_SYMBOL`이 0.1초마다 시그널한다(기본값이 심볼이라 도달하지 않는다).

### Mac의 characterIndexForPoint에서 글리프 행렬 접근을 가드한다
- 되살릴 때: quit 억제 중 NSNotFound 조기 반환만 항상 활성이라 그 3줄은 단독으로도 되살릴 수 있다(대신 그 상황에서 마우스 위치 조회가 실패한다). 이 빌드는 `INTERRUPT_INPUT`이라 `poll_suppress_count`가 상시 0이므로 조건은 사실상 `inhibit-quit` 단독이고, 영향받는 경로는 IME 조합이 아니라 마우스 클릭의 마크 텍스트 매핑·force-click 사전 조회·접근성 `AXRangeForPosition`뿐이다. 같은 부류 접근성 게터들이 보는 `gc_in_progress`는 `-[EmacsMainView string]`과 같이 보지 않는다.

### Mac의 markedRange에서 버퍼 접근을 가드한다
- 되살릴 때: hasMarkedText 조기 반환은 업스트림에 이미 있던 것이라 따로 떼어낼 부분이 없다. `firstRectForCharacterRange:`의 잠금 가드도 업스트림 것이므로 characterIndexForPoint 커밋에 의존하지 않는다. `markedRangeWithBufferAccess`는 업스트림 본문을 그대로 옮긴 것이라 hasMarkedText 조기 반환도 그대로 가진다.
- 되살릴 때 고칠 것: 가드 실패 시 `attributedSubstringForProposedRange:`가 unmarked 분기로 내려가는데, 그 분기는 조기 반환이 아니라 별도 trylock으로 버퍼 텍스트를 만들어 돌려주므로, 마크 텍스트가 있는 상태에서 같은 인덱스의 버퍼 내용을 마크 텍스트인 양 낼 수 있다. 도달은 Lisp 스레드 2개 이상 + 첫 trylock 실패뿐이다.

### Mac의 최소화 프레임 가시성 처리를 고친다
- 도달 경로: 반복 ICONIFY_EVENT는 special-event-map 처리(src/keyboard.c의 `initial_define_lispy_key`)와 while-no-input-ignore-events의 idle 복원으로 무해하다. 다만 매 라운드 kbd 버퍼에 이벤트가 쌓여 `input_pending`이 상시 참이 되므로 재표시 중단, `sit-for` 조기 반환, `recent_keys` 오염 같은 낭비는 있다(추정). 번쩍임과 포커스는 make-frame-visible 복원 경로(`window--maybe-raise-frame` 포함)에서 생긴다. Dock의 최소화 창 타일 클릭은 AppKit이 직접 복원해 무관하지만, 모든 프레임이 최소화된 채 Dock 앱 아이콘을 클릭하면 `mac-ae-reopen-application`의 첫 판정(`(eq (frame-visible-p f) t)`)이 최소화 프레임을 거르고 폴백 `filtered-frame-list`가 `frame-list` 순서(최근 생성이 앞)의 첫 `icon` 프레임을 골라 `select-frame-set-input-focus`로 가고, 그 `raise-frame` -> `mac_make_frame_visible`의 `!FRAME_VISIBLE_P` 분기로 이 경로에 들어간다. 데몬 커밋의 `mac-ae-select-frame-for-open`도 최소화 프레임만 있으면 하나를 `make-frame-visible`로 되살려 같은 분기에 들어간다(Finder odoc, org-protocol GURL). 실측: 프레임 하나가 최소화된 채 12초 동안 ICONIFY_EVENT가 67회 쌓였다(기대 1회). 전이를 거르던 가드는 GNU master 머지에서 사라졌다.
- 결정: 위 경로로 사용 조건에서 도달하지만 번쩍임은 세 번에 한 번꼴이고 최소화 자체를 거의 쓰지 않아 dev에 둔다. 이 커밋의 분류를 다시 검토할 필요는 없다.
- 의존: 데몬 커밋이 만든 applicationHiddenExplicitly와 활성화 커밋이 만든 mac_ensure_app_activated를 쓴다(dev 단독은 2 errors. 실측). 커밋 메시지는 upstream 위의 코드를 기준으로 쓰되 이 의존을 명시한다.
- 수정 방식: 최소화 복원은 `mac_show_frame_window`를 그대로 지나되 order-front만 건너뛴다(`deminiaturize:`가 창을 스스로 앞으로 가져온다). 명시적 hidden 중의 order-front 지연과 탭 그룹 처리는 no-focus-on-map 프레임에서도 유지되고, main 위에서는 활성화 정책 복원도 같이 유지된다. `isVisible`은 `deminiaturize:` 직후 이미 참이므로 show를 그 앞에 둔다.
- 되살릴 때: `suppressActivationOnDeminiaturize`는 `-windowDidDeminiaturize:`에서만 지워지므로 알림이 오지 않으면 다음 복원 때 활성화를 한 번 억누른다. 최소화 복원이 탭 그룹 로직(`exitTabGroupOverview` 포함)을 그대로 돌아 탭 오버뷰를 닫을 수 있다(미실측). order-front 없이 도는 탭 그룹 블록에서는 `exitTabGroupOverview`만 효과가 있다. 외부 프로세스가 `deminiaturize:`를 보내면 upstream에 없던 활성화 경로가 돌아 포커스를 가져간다(억제 플래그는 내부 hide 경로에서만 서고, Dock와 Mission Control은 macOS가 먼저 활성화해 frontmost 검사에 걸러진다).
- 미실측: `deminiaturize:` 직후 `isVisible`이 참이라는 전제(수정 전 순서에서는 그래서 show가 no-op였고 hidden 처리·탭 처리가 전혀 돌지 않았다는 것이 이 커밋의 실제 근거)를 실측하지 않았다.
- 미수정: Dock 클릭 경로의 두 번째 단계 `raise-frame` -> `mac_raise_frame` -> `mac_bring_frame_window_to_front`는 `order_front_p = true`라, `mac_handle_visibility_change`가 `isMiniaturized`를 거짓으로 읽은 뒤면 애니메이션 중 `orderFront:`가 그대로 나간다. 번쩍임의 남은 원인일 수 있다(추정). 되살릴 때 함께 본다.
- 미수정: `mac_hide_frame_window`가 최소화된 창에 `deminiaturize:` 뒤 `orderOut:`을 부르면 비동기 복원이 이겨 창이 다시 보이는 upstream 결함이 있다. `mac_handle_visibility_change`에는 죽은 `else if (visible == 1)` 분기가 남아 있고(30_1의 FRAME_OBSCURED_P 가드가 매크로째 사라졌다), `SET_FRAME_VISIBLE (f, visible)`이 int 2를 bool 시그니처에 넘겨 1로 뭉개진다.

### Org 수식 이미지의 두 배율을 모두 보존한다
- 증상: LaTeX를 설치하면 1배율 파일에 2배율 이미지가 덮여 비-Retina 화면에서 수식이 두 배로 보인다. 기본 프로세스가 dvipng(png)라 LaTeX만 깔면 기본 설정에서 바로 도달한다. `imagetype`이 svg면 `move2xfile`이 nil이라 2x 경로 자체가 없으므로, 그 절은 dvisvgm 계열로 바꿨을 때만 해당한다.
- 검증: 새 테스트는 org-compile-file을 스텁으로 바꿔 쓰기와 복사 순서, 그리고 두 변환의 DPI 인자(2x는 `?D`만 두 배이고 `?S`는 그대로다. dvipng/imagemagick은 `%D`만 쓴다)를 검증한다. DPI 단언은 2x의 `?D`가 1x의 두 배이고 `?S`가 같다는 관계식이라 org의 기본 DPI 상수에 묶이지 않는다. 수정 전 org.el에서 실패하고 수정 후 통과하는 것은 실행으로 확인했다.
- 미수정: 새 순서에서 2x 변환이 에러를 내면 1x 결과(`tofile`)만 남는다(수정 전에는 둘 다 안 남았다). upstream의 `mac_find_2x_image_file`이 `@2x` 형제 파일을 열지 못하면 nil을 돌려주어 1x 파일이 그대로 쓰이므로 무해하다.
- 상호작용: `@2x` 형제 파일이 있으면 `target_backing_scale`이 먼저 채워져 main에 있는 배율 1 커밋의 DPI 판정은 실행되지 않으므로 상쇄되지 않는다.
- 비용: org.el이라 머지 충돌 확률이 높다.

### play-sound-internal의 비지역 탈출에서 CFTypeRef 누수를 고친다
- 도달 경로: 쓰기 시작해도 play-sound-functions의 에러나 quit, 또는 객체 생성 직후 `unblock_input`의 pending signal 처리에서 빠져나갈 때만 샌다. 재생 중 quit은 이 포트에서 일어나지 않는다(구간 전체가 `block_input` 안이고, Lisp 스레드는 세마포어에 막혀 있으며 `mac_run_loop_run_once`에 `maybe_quit`이 없다). unwind 등록은 객체를 만드는 `block_input` 구간 안에 둔다. 바로 뒤 `unblock_input`의 pending signal 처리가 non-local exit 할 수 있기 때문이다.
- 미수정 없음: `record_unwind_protect_ptr`는 항목을 먼저 쓰고 `grow_specpdl`이 포인터를 올린 뒤에 실패하므로, specpdl 확장이 `memory_full`을 내도 등록한 해제는 되감긴다(풀 드레인 소절과 같다).

### Mac 파일 이름 강제 변환의 미초기화 결과 디스크립터를 고친다
- 도달 경로: Finder 열기(`mac-ae-open-documents` -> `mac-ae-parameter` -> `mac-coerce-ae-data`)와 드래그 앤 드롭(`mac-dnd-handle-file-url`)이 매번 지나는 함수지만, 결함 분기는 CoreFoundation이 URL로 받아들이지 않는 바이트열에서만 실행된다. 한글은 NFC·NFD 원바이트, 퍼센트 인코딩 모두 `CFURLCreateWithBytes`가 성공하고, 유효하지 않은 UTF-8(`FF FE FD` 등)만 NULL을 낸다(실측). 그때는 호출자 `Fmac_coerce_ae_data`가 미초기화 `dst_desc`를 쓰는데, `mac_aedesc_to_lisp`가 먼저 닿아 데몬 프로세스가 죽는다(실측. Lisp 에러가 아니다).
- 수정 방식: 핸들러가 `errAECoercionFail`을 돌려주게 하고, `Fmac_coerce_ae_data`의 `dst_desc`도 초기화해 다른 강제 변환 핸들러가 같은 실수를 해도 죽지 않게 한다.
- 검증: 커밋 메시지대로 GUI 세션에서 `(mac-coerce-ae-data "furl" (unibyte-string 255 254 253) 'undecoded-file-name)`으로 재현했다. 강제 변환 핸들러는 창 시스템 초기화에서만 설치되므로 배치로는 재현할 수 없다.
- 미수정: 같은 함수에서 다른 타입을 typeFileURL로 강제하는 분기의 `AEDesc desc`도 같은 부류로 미초기화인 채 남았다. 그 분기에는 트리가 설치하는 강제 변환 핸들러가 불리지 않아 도달하지 않는다.

### mac-reverse-video-cursor 옵션을 추가한다
- 결정: 설정(bar 커서)으로 필요를 없앤 커밋이지만, 박스 커서가 `cursor-type`의 기본값이라 돌아갈 수 있으므로 dev에 남긴다. 이 커밋의 분류를 다시 검토할 필요는 없다.
- 되살릴 때: 켜는 곳이 init-mac.el과 init-base.el의 주석에 남아 있다(t 설정과 isearch 훅 토글). bar와 hbar 커서는 비선택 창의 이미지 글리프 위에서만 `draw_phys_cursor_glyph`를 지나 옵션이 적용되고, 선택 창에서는 `get_window_cursor_type`이 hollow box로 바꿔 적용되지 않는다(docstring에 적었다).
- 한계: 옵션은 전역으로만 읽힌다. 창의 버퍼가 current가 되기 전에 판정하므로 setq-local 값은 무효이고, 값 자체도 current buffer 기준으로 프레임 전체에 적용된다.
- 범위: `lookup_basic_face`는 시그널하지 않게 쓰여 있어 `being_updated_p` 앞에 두는 배치는 방어적이다.
- 비용: 옵션을 켜면 `mac_update_window_begin`이 창마다·업데이트마다 `set_buffer_internal_1`과 `lookup_basic_face`를 돈다.
- 미수정: `cursor_default_face_id`는 `mac_update_window_begin`에서만 갱신되는데, GUI 스레드의 노출 경로(`drawRect:` -> `expose_frame` -> ... -> `mac_set_cursor_gc`)는 그것을 거치지 않고 `set-window-buffer`도 무효화하지 않으므로, face-remapping-alist 변경이나 버퍼 교체 직후 노출·커서 재그리기는 한 프레임 낡은 id로 판정한다. 다음 갱신에서 저절로 바로잡힌다.

### Mac 폰트 목록의 Core Foundation 객체 수명을 고친다
- 파킹 근거: 규칙상 traits dict의 빌린 값을 해제 뒤에 읽고 format 값을 해제하지 않는 것이 맞지만, 이 머신에 설치된 폰트(`CTFontCollectionCreateFromAvailableFonts` 디스크립터 757개)를 실측한 결과 traits dict는 참조계수가 1이 된 적이 없고 format CFNumber는 전부 태그드 포인터라 관측되는 효과가 0이다. CoreText 구현 세부이지 문서화된 계약이 아니므로 OS 업데이트나 폰트 설치로 바뀔 수 있어 보험으로 둔다.
- 범위: 같은 함수의 goto err 경로에 있던 families 누수(CTFontDescriptor 생성 실패)와 languages 과다 해제(폰트 패밀리 캐시 생성 실패. 뒤이은 attributes 해제로 이중 해제까지 갔다)도 이 커밋이 함께 고친다. 둘 다 드문 조건이다.

### Mac의 지연 Lisp 큐에 잠금을 건다
- 파킹 근거: 드레인과 append의 겹침은 GUI 블록이 `mac_within_lisp`로 Lisp를 되부른 뒤에만 생긴다(평상시 드레인 시점에는 GUI 스레드가 `mac_gui_loop`의 세마포어에 주차되어 append원이 없다). 되부르는 곳은 fullscreen->fullboth 전이, `tool-bar-lines` 있는 스타일 변경, 메뉴 help echo, DnD, 팝업 중 포커스 변화뿐인데 사용 조건은 어느 것도 밟지 않는다: init이 `tool-bar-lines`를 0으로 두고, `sunb-toggle-frame-fullboth`는 fullscreen 상태에서 nil을 넣어 fullscreen->fullboth 전이를 만들지 않으며 `mac-toggle-frame-fullscreen`도 그 전이를 만들지 않고, 메뉴와 팝업은 쓰지 않는다. DnD 되부름(`draggingUpdated:`)은 단일 스레드에서 `allowsLispEvaluationInDragging`이 상시 참이라 다른 앱에서 `mac-dnd-known-types` 기본값(URL, 문자열, TIFF)에 해당하는 것을 Emacs 프레임 위로 끌기만 해도 일어나므로, 이 전제는 정확히는 Emacs 창 위로 끌지 않는다는 것이고 다섯 경로 중 실수로 밟기 가장 쉽다. main의 알림 응답 핸들러 append는 메인 큐 블록이라 되부름 없이는 드레인과 겹치지 않는다. Lisp 스레드가 2개 이상이면 `mac_select`의 런루프와 다른 스레드의 `mac_within_gui` 사이에서 창이 넓게 열린다. 겹치면 GUI 스레드가 옛 포인터로 Lisp 스레드가 드레인 중이거나 이미 해제한 배열에 append 하고, 드레인의 마지막 빈 검사 뒤에 더해진 블록은 유실된다.
- 수정 방식: 잠금이 있으면 늦은 append가 새 배열에 들어가므로, 큐가 비었다고 단언하는 대신 빌 때까지 드레인한다. 옛 단언은 원래부터 불건전했고 잠금은 늦은 append를 결정적으로 만들 뿐이다.
- 되살릴 때: main으로 체리픽하면 알림 응답 핸들러와 fullscreen 재검사의 append도 잠금 안에 들어간다. main 위 3-way 체리픽은 무충돌이고, strict `git apply`는 `#import <os/lock.h>` 훅이 알림 커밋의 UserNotifications import 문맥과 어긋나 실패한다(실측).
- 비용: 잠금 안에는 포인터 읽기와 append, 빈 배열 할당뿐이고 블록 복사와 실행은 밖에서 하므로 측정되는 차이가 없다.
- 검증: 타이밍 의존이라 재현 테스트가 없다. main에 있을 때 -Werror 컴파일을 확인했고, dev로 옮기면서는 +/- 라인이 동일한 것만 확인했다(dev는 단독으로 빌드되지 않는다). 유실된 블록을 관측한 적은 없고, fullscreen 전이가 inner Lisp 호출 뒤에 동기로 append 하는지는 미실측이다.
- 비용(호환): `os_unfair_lock`은 macOS 10.12+라 이 포트의 소스상 최소 지원(10.6)을 조용히 올린다. `pthread_mutex_t`의 정적 초기화로 같은 결과를 낼 수 있다(바꾸지 않았다).

### macOS의 pty 읽기 처리량을 높인다
- 도달 경로: 로컬 ghostel 버퍼는 `ghostel-use-native-pty`(기본 t)로 네이티브 모듈이 pty를 직접 읽고 Emacs에는 `make-pipe-process`의 파이프만 주므로 이 커밋에 도달하지 않는다. 도달하는 것은 원격 버퍼나 옵션을 껐을 때의 `ghostel--spawn-via-emacs`(`:connection-type 'pty`)와, `process-connection-type` 기본값 t로 만들어지는 pty 서브프로세스다. 기본값 서브프로세스에서는 드레인 상한 64KB가 `read-process-output-max` 기본값과 같지만, 원격 ghostel 경로는 ghostel이 `read-process-output-max`를 1MB로, `process-adaptive-read-buffering`을 nil로 let-bind 한 채 프로세스를 만들므로 상한이 readmax의 1/16이다(readmax를 1MB로 올려도 드레인 상한이 64KB라 65536과 결과가 같다. 실측).
- 파킹 근거: 2026-09-01에 효과를 실측해 main에서 dev로 옮겼다. 이득이 왕복당 필터 고정 비용에 비례하고, 실제로 겪는 볼륨에서는 사라진다.
- 범위: LSP는 파이프라 무관하다. tty를 넘기는 `emacs_read` 호출처는 `read_process_output` 외에 src/keyboard.c의 `tty_read_avail_input`도 있어 터미널 Emacs의 큰 붙여넣기도 드레인 루프를 돈다(GUI 전용이라 무관). `emacs_read_quit`에 tty가 들어가는 경로는 `insert-file-contents`(fileio.c의 `emacs_fd_read`)로 tty 장치를 여는 것뿐이다. `process-adaptive-read-buffering`은 이 트리에서 기본값이 nil이고 init도 켜지 않으므로 그 판정 블록은 돌지 않는다. 켜면 드레인이 버퍼를 더 채워 readmax 분기에 닿을 수 있고 delay를 올리는 분기가 덜 돈다.
- 검증: 전제를 실측했다(Darwin 24.6에서 pty master `isatty`=1, `read(65536)`이 1024 반환, pipe는 65536 일괄). 성능 효과도 실측했다(2026-09-01, 설치된 Emacs.app 32.0.50). 드레인 진입 조건이 `result == 1024 && nbyte > result`이고 `nbyte`가 프로세스 생성 시점의 `read-process-output-max`이므로, 그 값을 1024로 두면 드레인이 꺼져 같은 바이너리로 패치 전후를 만들 수 있다. 드레인은 실제로 돌아 왕복당 1024B가 65536B가 되고 필터 호출이 8192회에서 128회로 준다(8 MiB). 그런데 8 MiB 포화 writer의 5회 중앙값이 필터에 따라 갈린다: 바이트만 세는 필터는 0.067초에서 0.077초로 15% 손해, 버퍼 삽입은 0.089초에서 0.082초로 8% 이득, ansi-color 적용은 0.204초에서 0.166초로 19% 이득이다. 즉 이득은 왕복당 필터 고정 비용에 비례하고, 필터가 싸면 pselect 추가 호출 때문에 오히려 손해다. 실제로 겪을 만한 크기에서는 이득이 사라져, 256 KiB에 ansi 필터로 20회 중앙값이 0.0088초에서 0.0083초로 0.5 ms 차이뿐이다. 드레인을 켜도 pty는 pipe보다 느리다(8 MiB, ansi: pty 0.166초, pipe 0.114초). 코드 주석의 성능 서술은 homebrew 패치에서 물려받은 것이라 단언을 지웠다.
- 미수정: 드레인 루프가 read의 EINTR에서 `interruptible`을 보지 않고 재시도하므로 `emacs_read_quit`에서는 드레인 중 quit이 지연된다(드레인은 64KB나 64회에 이르거나 읽을 것이 처음 없어지면 끝나므로 quit이 사라지지는 않는다). pselect의 EINTR은 드레인 종료로 취급해 효과만 준다. 성공 반환일 때 errno에 `ENOTTY`/`EAGAIN`/`EINTR`이 남는다(호출처가 음수 반환만 보므로 무해. 주석에 적었다).

### 배율 1 프레임에서 @2x 형제 파일을 읽지 않는다
- 도달 경로: `mac_preprocess_image_for_2x_file`을 지나는 것은 `slurp_image`를 쓰는 로더(WebP, XBM, XPM, PBM)와 SVG 파일 경로인데, 그 경로가 찾는 `@2x` 파일이 트리에도 설치된 패키지에도 없다(실측 2026-09-03).
- 범위: 배율 1 프레임에서 형제의 fd로 바꿔 끼우지 않을 뿐, 형제 파일 존재 확인(open/close)은 여전히 한다.
- 검증: 새 테스트가 임시 디렉터리에 8x8 XBM과 16x16 `@2x` 형제를 쓰고 배율 1에서 크기가 8x8인지 본다. 수정 전에는 `slurp_image`가 형제의 fd로 읽어 16x16이 나왔다. XBM을 쓴 것은 평문이라 픽스처가 필요 없고 ImageIO가 아니라 `slurp_image`를 지나는 로더이기 때문이다.
- 상호작용: dev의 "Org 수식 이미지의 두 배율을 모두 보존한다"를 되살리고 LaTeX를 설치하면 org가 `@2x` 파일을 만들므로 도달 조건이 생긴다. 그 커밋을 되살릴 때 함께 본다.
- 의존: 새 테스트 test/manual/mac-image-2x-file-tests.el이 main의 배율 1 커밋이 넣은 `image--set-test-frame-backing-scale-factor`를 쓰므로 main에서만 돈다(그 DEFUN은 `--enable-checking` 빌드에만 있다). 코드는 main 심볼에 의존하지 않는다.
- 순서: upstream 위에도 main 위에도 단독으로 strict `git apply` 된다(실측 2026-09-04). main의 배율 1 커밋과 `src/image.c`를 함께 고치지만 hunk가 겹치지 않고, 테스트 파일도 서로 다르다.
