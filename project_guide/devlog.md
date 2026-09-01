# 📖 개발 일지 (Devlog)

Git 커밋 로그만으로는 파악하기 힘든 기획 의도, 구조적 판단, 그리고 주요 대화(Context) 내용을 날짜별로 기록하는 문서입니다.

## 260901 - 배틀 중 ESC 키 일시정지 (PauseUI) 블러/어두운 배경 오버레이 구축 & 3중 클릭 차단
*   **작업 내용**:
    *   **배틀 일시정지 오버레이 컴포넌트 구축 (`PauseUI.gd`)**:
        *   `process_mode = Node.PROCESS_MODE_ALWAYS`로 설정하여 `get_tree().paused = true` 상태에서도 UI 입력 및 ESC 키 입력을 100% 독립적으로 처리.
        *   **SCREEN_TEXTURE 쉐이더 기반 블러 & 어두운 반투명 틴트 오버레이** 적용: 뒤쪽 배틀 씬이 부드럽게 블러/암전 처리되어 중앙 일시정지 메뉴가 뚜렷하게 도각되도록 연출.
        *   `backdrop.mouse_filter = Control.MOUSE_FILTER_STOP`으로 설정하여 **뒤쪽 3D 체스 보드 및 3D 카드 클릭 흡수 차단 (3중 클릭 차단)**.
        *   **버튼 메뉴 연동**:
            *   `Resume`: 게임 일시정지 해제(`get_tree().paused = false`) 및 UI 삭제.
            *   `Option`: 미구현 풋프린트.
            *   `Title`: 게임 일시정지 해제 후 `res://Scene/TitleScene.tscn`으로 씬 전환.
            *   `Quit`: `get_tree().quit()`으로 안전한 게임 종료.
    *   **스테이지 선택 화면 좌측 상단 뒤로가기 버튼 추가 (`Stage.tscn` & `StageManager.gd`)**:
        *   `Stage.tscn` 좌측 상단(`offset_left=30, offset_top=30`)에 `BackButton`(`← 뒤로가기`) 배치 (요청에 따라 일관성을 위해 호버 확대 제거).
        *   클릭 및 ESC 핫키 입력 시 `res://Scene/TitleScene.tscn`으로 심리스 복귀 기능 연동.
    *   **영구 데이터(Permanent) vs 휘발성 런 스냅샷(Current Run) 이원화 세이브 구축 (`ProfileManager.gd`, `TitleManager.gd`, `BattleManager.gd`)**:
        *   `ProfileManager.gd` 스키마 개편:
            *   `permanent_data`: 계정 해금 기물(`unlocked_cards`), 누적 플레이 통계(`total_runs`, `wins`) 보존.
            *   `current_run`: 휘발성 런 상태 (`is_in_run`, `current_stage_id`, `master_deck`, `stage_snapshot`).
        *   `save_stage_snapshot()`: **스테이지 시작 직후**의 체스 보드 기물 배치(`board_state`), 남은 덱(`draw_pile`), 손패(`hand`), 버린 덱(`discard_pile`)을 스냅샷으로 채록하여 저장.
        *   `TitleManager.gd` 연동:
            *   `Continue` (이어하기) 버튼: `has_active_run() == true` 일 때만 동적으로 활성화되며, **클릭 시 비동기 사전로딩 및 최상단 검은색 페이드아웃(0.35s) ➔ 배틀 씬 비동기 로딩 ➔ 스무스 페이드인 연동**을 똑같이 구현하여 회색 잔상 없는 심리스 이어하기 전환 완료.
            *   `New Game` (새 게임) 버튼: 기존 런 데이터를 리셋(`start_new_run()`)하고 신규 런으로 시작.
        *   `RewardUI.gd` 연동: 최종 스테이지(Stage 3) 완료 시 `clear_current_run()`을 호출하여 런 휘발성 데이터를 안전하게 소멸.
    *   **카드 에셋 명명 규칙 표준화 및 전술 카드 8종 데이터베이스 구비 (`CardData.gd` & `ProfileManager.gd`)**:
        *   `T_` 접두사: **전술(Tactic/Spell) 카드** (예: `T_Crusade.png`, `T_Disband.png` 등)
        *   `W_` 접두사: **백색 아군 기물 카드** (예: `W_Pawn.png`, `W_Knight.png` 등)
        *   `B_` 접두사: **흑색 적군 기물 카드** (예: `B_Pawn.png`, `B_Knight.png` 등)
        *   전술 카드 8종(`t_crusade`, `t_disband`, `t_lance_charge`, `t_last_stand`, `t_quick_decision`, `t_sabotage`, `t_spoils`, `t_two_cats`)을 `CardData.gd` 정적 데이터베이스에 공식 구비 완료.
    *   **전술 파워 카드 [십자군 / Crusade] 기능 구현 (`ChessRules.gd`, `BoardManager.gd`, `CardManager.gd`)**:
        *   `t_crusade` 카드 사용 시 전투 전역 특수 규칙 `bishop_straight_move` 활성화 (`BoardManager.add_custom_rule`).
        *   `ChessRules.gd` 행마법 확장: `is_white` (아군 백색 기물) 조건과 `bishop_straight_move` 규칙이 충족되면 아군 비숍이 대각선뿐만 아니라 **직선(상/하/좌/우)으로도 경로 방해물 검사(`_is_path_clear`) 후 이동 가능**하도록 구현.
        *   팝업 연출 없이 플레이어가 카드 사용 후 자연스럽게 이동 하이라이트(3D 닷) 및 선택 지점을 통해 직진 이동 가능하도록 심리스하게 통합.
        *   **기물 관련 전술 카드 사멸(Exhaust) 자동 연동 (`CardManager.gd`)**: `t_crusade` (`"Bishop"`), `t_lance_charge` (`"Knight"`), `t_quick_decision` (`"King"`) 등 특정 기물 태그가 포함된 전술 카드도 체스판 위의 해당 아군 기물이 전멸했을 시 드로우 시점에 `[ BISHOP ] 기물 전멸!`과 함께 자동으로 공중 클로즈업 및 소멸(Exhaust)되도록 기물 태그 판별 시스템(`valid_piece_tags`) 고도화 완료.
        *   **파워(Power) 및 소멸(Exhaust) 카드 연출 및 메커니즘 통합 (`CardManager.gd`)**: `CardType.POWER` 타입 및 `"Power"`, `"Exhaust"` 태그 카드가 사용될 때 우측 하단 버린 덱으로 빨려 들어가지 않고, **화면 정중앙 카메라 앞으로 올라와 클로즈업된 후 투명하게 페이드 아웃 소멸(`_animate_exhaust_from_hand`)**되면서 소멸 덱(`exhaust_pile`)으로 이동하도록 연출 및 메커니즘을 시각적으로 통일.
    *   **전술 스킬 카드 [소집 해제 / Disband] 기능 구현 (`ChessRules.gd`, `BoardManager.gd`, `CardManager.gd`, `ProfileManager.gd`)**:
        *   `t_disband` (코스트 0) 카드 사용 시 `BoardManager.add_friendly_capture_charge(1)`을 통해 이번 턴에 한해 아군 포획 기능(`allow_friendly_capture`) 1회 부여.
        *   `ChessRules.gd` 검증 확장: `allow_friendly_capture` 규칙 활성화 시 아군 기물이 위치한 타일도 유효 이동 경로로 인정 (단, 아군 킹 기물은 자멸 방지를 위해 포획 불가 예외 처리).
        *   아군 기물 포획 시 `consume_friendly_capture_charge()`로 즉시 1회 차감되며 규칙이 자동 해제됨. 턴 종료시(`CardManager.end_turn`) 잔여 충전 횟수는 0으로 리셋.
        *   기본 지급 덱 구성(`ProfileManager.gd`, `PlayerData.gd`)의 테스트 카드를 `십자군(t_crusade)`에서 **`소집 해제(t_disband)`**로 변경 완료.
    *   **전술 스킬 카드 [랜스 차징 / Lance Charge] 메커니즘 고도화 (`ChessRules.gd`, `BoardManager.gd`, `CardManager.gd`, `ProfileManager.gd`)**:
        *   **대기(Pending) 콤보 시스템**: `t_lance_charge` 카드 사용 시 즉시 행동권을 주는 대신 `lance_charge_pending` 대기 플래그가 켜지며, 이후 플레이어가 **[나이트 기물 카드]를 사용하는 순간 행동권 +2개와 점프 불가(`knight_no_jump`) 버프가 차징 발동**되도록 콤보 메커니즘 구축.
        *   **단일 나이트 임시 포인터 및 2회 이동 제한 (`lance_charge_target_knight`)**: 
            *   차징 발동 후 플레이어가 체스판 위에서 최초로 움직인 특정 나이트 하나만 `lance_charge_target_knight` 포인터로 지정되며 해당 나이트에만 `max_moves = 2`가 선택적으로 부여됨.
            *   2회 이동이 완전히 끝나기 전까지는 다른 아군 기물을 클릭하더라도 이동 하이라이트가 생성되지 않도록 조작을 제한(`show_valid_moves`).
            *   해당 나이트가 2회 이동을 완전히 마치면 `max_moves = 1` 복구 및 임시 포인터와 `knight_no_jump` 점프 차단 룰이 완벽히 원복됨.
        *   **2차 이동 조작성 개선 (`BoardInput.gd`)**: 1차 이동 성공 시 `selected_piece` 선택을 해제하지 않고 유지하며, 새로 이동한 위치 기준의 2차 이동 3D 닷 하이라이트(`show_valid_moves`)를 자동 갱신하여 2번째 이동이 바로 연속 가능하도록 심리스 연동 완료.
        *   `ChessRules.gd` 행마법 검사: 나이트의 직진 1칸 앞 인접 길목 타일(상/하/좌/우)에 기물이 막혀 있을 경우 대각선 점프 이동을 차단하도록 경로 검사 적용.
        *   기본 지급 덱 구성(`ProfileManager.gd`, `PlayerData.gd`)의 테스트 카드를 **`빠른 판단(t_quick_decision)`**으로 변경 완료.
    *   **전술 스킬 카드 [빠른 판단 / Quick Decision] 기능 구현 (`BoardManager.gd`, `CardManager.gd`, `Piece.gd`, `ProfileManager.gd`)**:
        *   `t_quick_decision` (코스트 1) 사용 시 `BoardManager.apply_quick_decision()`을 호출하여 킹의 현재 턴 내 행동 상태(`move_count`)를 검사.
        *   **이동 횟수 중복 카운트 버그 수정 (`BoardInput.gd`, `AITestRunner.gd`)**:
            *   `BoardManager.attempt_move()` 내부에서 `record_move()`가 1회 실행되고 있음에도 불구하고 `BoardInput`과 `AITestRunner`에서 중복 호출되어 1회 이동 시 `move_count`가 2로 급증하던 결함을 해결.
            *   중복 호출 제거를 통해 킹 1회 이동 시 `move_count = 1`이 정확히 기록되며, `빠른 판단` 카드 사용 시 `move_count`가 `1 ➔ 0`으로 차감되어 킹의 2차 이동이 완벽하게 구동됨.

---

## 260831 - 이벤트 기반 사멸 기물 카드 중앙 클로즈업 & [기물 전멸] 3D 텍스트 페이드아웃 소멸(Exhaust) 구축
*   **작업 내용**:
    *   **이벤트 기반 기물 전멸 감지 최적화 (`BoardManager.gd`)**:
        *   실시간 탐색 연산 비용을 제거하기 위해, 아군 기물이 포획(Capture)되는 순간에만 `_check_and_register_eliminated_piece_type(captured_piece)`를 호출.
        *   잡힌 기물 종류의 동일 아군 기물이 체스판 위에 0개 남아있음을 확인 시, `eliminated_player_piece_tags` 소멸 플래그 목록에 등록.
    *   **카메라 중앙 클로즈업 & 3D 텍스트 안내 페이드아웃 연출 (`CardManager.gd` & `CardVisual3D.gd`)**:
        *   `CardVisual3D.gd`에 `set_card_alpha(alpha)` 헬퍼를 작성하여 카드 앞/뒷면 메쉬의 투명도를 일괄 제어 가능하도록 보강.
        *   드로우 시 사멸된 기물 카드도 일단 정상적으로 손패 슬롯 위치로 날아와 착지.
        *   착지 직후, 해당 사멸 카드가 **`CardManager` 씬 카메라 시점 정중앙(`to_global(Vector3(0, 0.8, 0.5))`)으로 클로즈업(`scale 0.5`)**하여 명확하게 카드를 노출.
        *   카드 전면에 **하얀색 글씨 + 뚜렷한 검은색 테두리 외곽선**의 3D 텍스트 안내(`Label3D`: `[ PAWN ] 기물 전멸!`) 팝업 (**0.8초간 대기**하여 소멸 원인을 충분히 판독).
        *   대기 후 **3D 카드와 전멸 안내 텍스트가 동시에 투명해지며 페이드 아웃(0.5초 Fade-Out)**하여 완전 소멸 (`queue_free()`).
        *   소멸 완료 후 남아있는 손패 카드들이 부드럽게 중앙으로 자동 재배치 (`_recalculate_hand_positions()`).
    *   **비동기 사전로딩 & 루트 레이어 기반 심리스 씬 전환 (`StageManager.gd`)**:
        *   `add_child(fade_layer)` 대신 **`get_tree().root.add_child(fade_layer)`**를 적용하여, `change_scene_to_packed` 시 씬이 파괴되는 순간에도 검은 페이드 레이어가 화면 최상단(Window Root)에 파괴되지 않고 100% 지속 유지되도록 보강.
        *   `change_scene_to_packed` 호출 후 `StageManager`가 트리에서 이탈할 때 발생하던 `get_tree() -> null` 오류를 막기 위해, 미리 확보한 `fade_layer.get_tree()`의 참조를 사용해 1프레임 후 오버레이가 안전하게 cleanup 되도록 예외 처리 완료.
        *   스테이지 버튼 클릭 즉시 비동기 로딩(`ResourceLoader.load_threaded_request`) 가동 ➔ 검은 화면 스무스 페이드아웃(0.35s) ➔ 100% 암전 속 씬 전환 ➔ 배틀 씬 스무스 페이드인(0.35s)으로 대칭 연동되어 **회색 화면 깜빡임이 0.001초도 보이지 않는 완벽한 씬 전환** 완성.
    *   **캐슬링 (Castling) 규칙 및 3D 동시 이동 구현 (`ChessRules.gd` & `BoardManager.gd`)**:
        *   `ChessRules.gd` 킹 규칙에 캐슬링 조건 추가: 킹과 대상 룩의 미이동(`move_count == 0`) 및 경로 빈 공간 판별.
        *   `BoardManager.gd`에서 킹 2칸 이동 시 킹과 룩이 동시에 3D 슬라이드(Tween)하며 보드 딕셔너리(`current_board_state`)를 갱신하도록 구현.
    *   **동적 폰 프로모션 (Pawn Promotion) & 카드 덱 연동 (`PromotionUI.gd` & `BoardManager.gd`)**:
        *   `Grid.current_grid_info.get("max_row", 8)`를 활용하여 가변 체스판에서도 최후열 행 도달(백: `max_row`, 흑: `1`) 시 승급을 감지하는 동적 로직 구성.
        *   플레이어 폰 승급 시 카드 소멸 연출 시퀀스 양식과 일치시킨 **`[ PROMOTION ]` 헤더** 및 **4장의 기물 카드(퀸, 룩, 비숍, 나이트 일러스트/호버 micro-animation, 설명 텍스트 제외하여 시각적으로 군더더기 없이 깔끔하게 조율)** 선택 UI(`PromotionUI.gd`)로 개편 (AI 흑 폰은 자동 퀸 승급).
        *   승급 시 기존 폰 파괴 후 승급 기물 3D 모델을 스냅 배치하며(기존 폰의 `get_parent()` 부모 계층 및 `pawn.scale`을 완벽히 상속받아 **크기가 비대해지는 현상 방지 및 체스판 비율 100% 동기화**), 승급한 기물의 **전멸/사멸 플래그(`eliminated_player_piece_tags`)를 자동 해제**하고 **해당 기물 카드 1장(`w_queen`, `w_rook` 등)을 버린 덱이 아닌 플레이어의 손패로 즉시 추가(`add_card_directly_to_hand`)**하여 드로우 애니메이션과 함께 바로 사용할 수 있도록 완성.
    *   **스테이지 연속 진행 처리 (`RewardUI.gd`)**:
    *   **창 크기 변경 시 반응형 비율 확대/축소 및 3D 카드 위치 동기화 (`project.godot` & `BattleManager.gd`)**:
        *   `project.godot`에 `window/stretch/mode="canvas_items"` 및 `window/stretch/aspect="keep"` 설정 적용. 극단적인 직사각형/세로형 창 변경 시에도 **16:9 화면 비율(1600x900)을 레터박스(레터박싱/필러박싱)와 함께 100% 완벽히 유지**하여 체스판과 카드의 좌표 왜곡 방지.
        *   `CardVisual3D.gd` 및 `CardManager.gd`의 카드 3D 메쉬 및 콜리전 크기를 `Vector2(1.0, 1.5)`로 통일하여 **일반 카드 에셋 해상도(800x1200 / 2:3 비율)에 맞춰 3D 카드가 앞뒤 찌그러짐 없이 100% 동일하게 일치**하도록 조율.
*   **핵심 의도 및 대화 요약**:
    *   기물 전멸 시 포획 연출과 심리스 씬 전환 및 Stage 3 연속 진입 연결을 완성함. 나아가 체스 표준 캐슬링(킹/룩 동시 이동)과 동적 보드 응용 폰 프로모션(카드 나열 UI 팝업, 기물 전멸 플래그 복구, 승급 기물 카드 손패 직접 추가) 및 창 크기 변경 시 반응형 3D 동기화 시스템을 성공적으로 구축함.

## 260830 - CHESSHIRE 타이틀 씬(TitleScene) UI & 스테이지 선택 씬(Stage.tscn) 구축 및 Stage 1 연동
*   **작업 내용**:
    *   **타이틀 UI 레이아웃 구축**: `Scene/TitleScene.tscn`에 화면 좌측 상단 게임 제목(`CHESSHIRE`) 및 좌측 중앙 메뉴 버튼 모음(`VBoxContainer`) 구성. 프로젝트 시작 씬(`run/main_scene`)을 `TitleScene.tscn`으로 지정.
    *   **버튼 배치 및 스크립트 분리**: `New Game`, `Continue`, `Option`, `Quit` 4개 버튼 배치 및 `scripts/ui/TitleManager.gd`로 컨트롤 연결. `New Game` 클릭 시 `Scene/Stage.tscn`으로 씬 전환 연결.
    *   **스테이지 선택 씬(`Scene/Stage.tscn`) 구성 및 Stage 1 데이터 연동**:
        *   **어둡고 블러 처리된 배경**: 타이틀 이미지(`ChesshireTitle.png`)의 밝기를 낮추고(`Color(0.4, 0.4, 0.4, 1)`), 캔버스 셰이더(`hint_screen_texture`)를 기반으로 은은한 화면 블러(Blur) 효과 적용.
        *   **스테이지 가로 배치 버튼**: 화면 정중앙(`HBoxContainer`)에 큼직한 `Stage 1`, `Stage 2`, `Stage 3` 버튼 가로 배열 (간격 80px).
        *   **Stage 1 게임 연동**: `stages.json`에 상대방 퀸/비숍/룩 및 특정 폰이 제거된 커스텀 `stage1` 데이터 정의. `Stage 1` 버튼 클릭 시 `BoardManager.current_stage_id = "stage1"` 설정 후 `Battle_Scene.tscn`으로 씬 진입되도록 완성.
    *   **승리 목표 용어 리팩토링 (`VIP_Target` ➔ `Objective`)**:
        *   이동 대상 타일(`target_tile`)과의 명칭 혼선을 막기 위해 체스 킹 등 승리 목표 기물의 식별 태그 및 그룹명을 `VIP_Target`에서 `Objective`로 전면 변경 (`CardData.gd`, `CardManager.gd`, `AITestRunner.gd`).
    *   **AI 점수 평가 하한선 보완 (`highest_score = -INF`)**:
        *   CHESSHIRE 특성상 체크메이트(외통수) 상태여도 해당 카드가 드로우되지 않으면 물리적으로 잡을 수 없으므로, 코너에 몰려 감점이 극심한 상황에서도 AI가 턴을 포기/스킵하지 않고 끝까지 최선의 이동을 수행하도록 평가 하한선을 `-INF`로 수정.
    *   **실행 파일 동등 디렉토리 프로필 세이브 시스템 (`ProfileManager.gd`)**:
        *   에디터 및 배포된 `.exe` 실행 파일 위치의 `profile/` 디렉토리에 닉네임 기반 JSON 세이브파일(`player.json`)이 자동 생성 및 동기화되도록 구현.
        *   `permanent_data`(영구 해금)와 `current_run`(단기 런 마스터 덱)을 이원화 관리하도록 설계 및 `DeckComponent` / `CardManager` 연동 완료.
    *   **Stage 2 데이터 작성 및 버튼 연동**:
        *   `resources/data/stages.json`에 풀 정규 체스 기물 배치인 `stage2` 데이터 추가.
        *   `Stage.tscn`의 `Stage 2` 버튼 클릭 시 `BoardManager.current_stage_id = "stage2"` 설정 후 배틀 씬으로 진입하도록 `StageManager.gd` 연동.
    *   **승리("VICTORY!") & 패배("DEFEATED") 연출 및 보상 UI (`RewardUI.gd`) 구축**:
        *   `BoardManager.gd`에서 상대 `Objective` 포획 시 중앙 대형 황금빛 "VICTORY!" 서체 확대 연출 ➔ `ProfileManager` 해금 카드 기반 보상/정제 UI 팝업.
        *   아군 `Objective` 포획 시 중앙 대형 핏빛 "DEFEATED" 서체 확대 연출 ➔ 2초 후 패배 처리 및 스테이지 선택 재시도 오버레이 제공.
        *   `CenterContainer` 레이아웃 구조로 전면 개편하여 승리/패배/보상/카드삭제 등 모든 연출 및 팝업 UI가 어떠한 해상도에서도 화면 정중앙에 100% 정밀하게 배치되도록 보강.
*   **핵심 의도 및 대화 요약**:
    *   메인 타이틀 -> 스테이지 선택 -> 커스텀 스테이지 진입 흐름 및 승리("VICTORY!") / 패배("DEFEATED") 연출, 해금 데이터 기반 보상 획득/카드 정제 UI(`RewardUI.gd`)까지 완성하여 로그라이크 덱빌딩 코어 루프를 성공적으로 구축함.

## 260821 - 플레이어 진영(Player Team) 기반 기물 제어 및 카드 행동권 격리
*   **작업 내용**:
    *   **진영 감지 로직**: `Piece.gd`에 `get_team()` 헬퍼 추가, `BoardManager.gd`에 `@export var player_team: PieceData.Team` 및 `is_player_piece()` 구현.
    *   **아군 기물 제약 및 AI 동적 인식**: `BoardInput.gd`에서 아군 기물만 클릭 가능하도록 차단하고, `AITestRunner.gd`가 플레이어 진영을 자동으로 피하여 적군 기물만 제어하도록 연동.
*   **핵심 의도**:
    *   플레이어가 백색/흑색 어느 진영을 플레이하더라도 코드 수정 없이 변수 하나로 완벽하게 자신의 기물 및 카드가 동작하도록 흑/백 역할 자동 전환 구조 구축.

## 260718 - 턴 시스템 자동화 및 다중 행동 AI 도입
*   **작업 내용**:
    *   **기물 카드(Piece Cards) 시스템 연동**: 체스 기물들을 조작하기 위한 전용 카드 에셋들을 DB(`CardData.gd`)에 정식 편입하고, 턴당 다중 행동 규칙에 맞추어 카드 코스트 밸런스를 전체적으로 재조정함.
    *   **기물 이동 횟수 제어**: `Piece.gd`에 `move_count`와 `max_moves` 변수를 도입하여 한 턴에 하나의 기물은 최대 1번만 움직일 수 있도록 강제(`has_method("can_move")` 기반 검증).
    *   **AI 다중 행동(Multi-action) 구현**: `AITestRunner`에 `@export var ai_actions_per_turn = 2`를 추가하여 한 턴에 2개의 다른 기물을 움직이도록 고도화. 특히 매 행동마다 체스판 변화를 즉각적으로 재평가(Re-evaluation)하여 능동적인 콤보 플레이가 가능하도록 설계.
    *   **턴 사이클 자동화**: 수동 버튼 클릭 방식에서 벗어나, 플레이어 턴 종료 -> 손패 버리기 애니메이션 대기(0.5초) -> AI 턴 실행(행동 간 0.4초 딜레이) -> 자동으로 내 턴 시작(드로우 및 코스트 회복)으로 이어지는 완전한 자동 턴 시퀀스 연결.
    *   **UI/UX 및 디버그 환경 개선**: Godot 엔진 로고(Splash Screen) 숨김 처리, 단독 AI 테스트용 UI 주석 보존, 턴 종료 스페이스바 단축키 추가, 불필요한 GDScript 경고(`UNUSED_PARAMETER`) 해결 및 손패 UI 레이아웃 순서 개편.
*   **핵심 의도 및 대화 요약**:
    *   체스와 카드 게임이 섞였을 때 발생하는 극심한 난이도와 자원 관리의 재미를 확인하고 밸런스 방향성을 논의함.
    *   AI가 한 번에 두 가지 최선의 행동을 기계적으로 계산해 내는 것이 오히려 체스의 전통적 룰을 부수어 강력해짐을 관찰. 향후 플레이어의 "특수 카드(스킬)" 도입으로 이를 어떻게 카운터칠지 기획적 기대감을 나눔.

## 260715 - AI 1-Ply 휴리스틱 엔진 고도화 및 튜닝
*   **작업 내용**:
    *   **방어 점수 능동/수동 분리**: `WEIGHT_ACTIVE_DEFENSE_RATIO`(20%), `WEIGHT_DEFENSE_RATIO`(5%)로 세분화하여, 위협받지 않는 아군에 대한 무의미한 진형 유지 집착 완화.
    *   **위협 제거 보너스 도입**: 하위 기물로 상위 기물의 위협을 제거할 때 30%(`WEIGHT_THREAT_REMOVAL_BONUS`)의 보너스 점수를 부여하여 교환 이득 장려.
    *   **포획 시 인질극(Hostage Exploit) 버그 해결**: '위협' 상태의 득점이 '포획' 득점보다 커서 기물을 살려두고 점수만 뽑아먹는 수학적 버그를 발견. 이를 비보호 기물 '포획' 시 보너스(`WEIGHT_UNPROTECTED_CAPTURE_BONUS`)로 수정.
    *   **근위대 마비(Royal Guard Paralysis) 현상 해결**: 킹(VIP)처럼 포획되면 게임이 끝나는 타겟은 '교환'을 전제로 하는 방어 점수 가치가 없음을 파악하여, 메인 타겟은 아군 방어 점수 산정 로직에서 0점으로 제외.
*   **핵심 의도 및 대화 요약**: 
    *   휴리스틱(점수 기반) 엔진의 한계로 인해 발생하는 "왜 뻔한 걸 안 잡지?"라는 의문을 수식적으로 분석하고 튜닝함.
    *   체크메이트 시 AI가 굳는 이유는 합법적 이동 수가 0이 되는 정상적인 로직임을 확인.
    *   1수 앞(1-Ply)만 보는 현재 로직의 한계를 명확히 하고, 향후 Minimax 알고리즘 도입의 필요성을 기획적으로 논의함.

## 260701 - 체스 AI 두뇌(Heuristic) 프로토타입 개발 및 BattleScene 연동
*   **작업 내용**:
    *   **독립된 AI 테스트 환경 구축**: 카드 시스템과 엮이지 않은 순수 체스 인공지능 로직을 테스트하기 위해 `scripts/ai/` 디렉토리 및 `AITestRunner.gd` 신규 생성.
    *   **가중치 기반 득실 계산(Heuristic) 로직 구현**: 적 위협, 지형 통제, 기물 가치를 종합하여 가장 높은 점수의 행동을 선택하는 1수 앞(1-Ply) 평가 함수 기초 작성.
    *   **BattleScene 연동**: 작성된 AI 엔진을 메인 전투 씬에 올려, 턴 종료 시 흑색(Enemy) 기물들이 스스로 판단하여 타일로 이동하는 적군 턴 사이클 완성.
*   **핵심 의도 및 대화 요약**: 
    *   "생각하는 체스 AI는 어떻게 판단하는가?"에 대한 의문을 시작으로, 미니맥스(Minimax) 알고리즘과 유틸리티(Utility) AI의 차이를 심도 있게 논의함.
    *   복잡한 콤보보다 보드 전체의 가치를 실시간으로 평가하는 득실 기반 구조가 우리 프로젝트에 더 적합하다는 기획적 방향성을 합의함.

## 260630 - 드로우/버리기 애니메이션 최적화 및 FSM 도입
*   **작업 내용**:
    *   **다이렉트 비행 연출**: 5장 드로우 시 카드가 공중에서 옆으로 밀려나는 현상을 방지. 배열에 5장을 즉시 할당하여 최종 목표 좌표를 도출하고, Tween의 위치 간섭을 삭제한 뒤 기존 `lerp`에 비행을 전담시켜 가장 자연스러운 궤적 완성.
    *   **FSM(상태 머신) 도입**: `CardManager`에 `IDLE`, `DRAWING` 상태를 추가. 드로우 연출(`execute_drawing`)이 진행되는 동안 플레이어의 마우스 입력을 원천 차단.
    *   **버린 카드 더미 연출**: 우측 하단(X: 5.4)에 대칭되는 버린 덱 모델 생성. 카드를 사용하면 가속(`EASE_IN`)하며 크기가 줄어들고 덱으로 빨려 들어가는 시각적 피드백(Tween) 추가.
    *   **카드 확인(Viewer) 시스템**: 남은 덱이나 버린 덱 모델을 클릭 시 화면이 어두워지고 해당 덱의 카드들을 가로 5열 그리드로 보여주는 2D UI 시스템(`execute_card_view`) 구현 및 `VIEWING` 상태 추가.
    *   **3D 양면 카드 구현**: 카드 메쉬를 2장 겹치고 뒷면용 메쉬를 180도 뒤집어 `card_back_test.png`를 적용.
*   **핵심 의도 및 대화 요약**: 
    *   Tween과 Process(Lerp)의 충돌 원리를 깨닫고 장점만 취합하여 최적화함. 엔진 내장 곡선(CUBIC, EASE_IN)의 수학적 원리를 상황에 맞게 적용함.
    *   복잡해지는 아키텍처의 기준을 잡기 위해 `reminder.md` 신설 합의.

## 260628 - 3D 카드 시스템 코어 도입 및 시각화
*   **작업 내용**:
    *   **카드 시스템 코어**: `CardManager`, `CardVisual3D`, `CardData`, `PlayerData`, `DeckComponent` 생성.
    *   화면 좌측 하단에 3D 덱 뭉치 및 남은 카드 카운터 구현.
    *   각종 스킬 카드 아이콘 리소스(`arcane_bolt_icon.tres` 등) 대량 추가 및 세이브 파일 로드 오류(`.assign()`) 해결.
*   **핵심 의도 및 대화 요약**:
    *   체스판과 어우러지는 몰입감을 극대화하기 위해 2D UI가 아닌 **완전한 3D 환경의 보드게임 형태**로 덱 빌딩 디자인 방향 확정.

## 260626 - 체스 그리드(Grid) 논리 구조 최적화
*   **작업 내용**:
    *   `Grid.gd` 신규 생성 및 `BoardManager` 로직 리팩토링.
*   **핵심 의도**: 체스판의 물리적 3D 좌표와 논리적 좌표(배열 인덱스)를 더 깔끔하게 분리하기 위한 기초 다지기.

## 260625 - 체스 룰(ChessRules) 엔진 탑재
*   **작업 내용**:
    *   `ChessRules.gd` 신규 생성 및 `BoardInput`, `BoardManager` 업데이트.
*   **핵심 의도**: 기물별 이동 규칙(행마법)과 상호작용 논리를 독립된 룰(Rules) 엔진으로 완벽히 분리하여 버그를 줄이고 확장을 용이하게 함.

## 260622 - 체스 기물(Piece) 3D 애셋화 및 컴포넌트화
*   **작업 내용**:
    *   블렌더(`piece.blend`) 원본과 텍스처를 바탕으로 흑/백 모든 체스 기물의 프리팹(`B_Bishop.tscn` 등) 대량 생성.
    *   `GridDetectorComponent` 생성 및 스테이지 데이터(`stages.json`) 연동.
*   **핵심 의도**: 기물들을 개별 노드로 쪼개고 컴포넌트 중심(Composition)으로 설계하여, 데이터 주도 설계(Data-Driven Design) 원칙의 뼈대를 세움.

## 260621 - 보드(Board) 입력 및 제어 시스템 구축
*   **작업 내용**:
    *   `BoardGrid.gd`, `BoardInput.gd`, `Piece.gd`, `PieceData.gd` 생성.
    *   지저분했던 에셋 폴더 구조 정리(`.backup` 분리).
*   **핵심 의도**: 플레이어의 마우스 클릭 조작(Input)을 체스판의 그리드 좌표계로 빠르고 정확하게 변환하기 위한 제어 시스템 설계.

## 260620 - 프로젝트 초기화 및 3D 보드 세팅
*   **작업 내용**:
    *   체스판 3D 모델(`chess_board.glb`) 및 텍스처 임포트, 최초의 `BattleScene.tscn` 생성.
    *   `project_guide/` 폴더 산하에 기획서 및 구조 문서 세팅.
*   **핵심 의도**: 3D 체스/카드 게임 개발을 위한 기초 환경 구축 및 Git 버전 관리 시스템 연동 시작.
