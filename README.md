
## 체스 AI 및 게임시스템

## **휴리스틱 기반 점수 평가**

- 일정한 기준에 따라 각 기물의 획득 가능한 행동 별 점수 연산 후 가장 높은 점수 획득하는 행동 선별 후 난이도에 따라 확률적으로 시행

## 점수 연산 로직

- 각 기물별로 점수 할당 : 각 기물별로 기존 체스의 기물 가치를 반영해 점수 할당
- 영향력 : 각 좌표에 가치를 부여, 가치가 높은 중앙일수록, 상대 진영일수록 가중치, 기물이 개입 가능한 좌표들의 가치만큼 합산
- 위협 : 이동가능 좌표 내에 있는 상대방 기물 가치의 일정 비율만큼 점수에 합산, 해당 행동이
- 보호 : 이동가능한 좌표 내에 있는 아군 기물 가치의 일정 비율만큼 점수에 합산
- 회피 :
- 반격 : 공격가능한 기물이 있는 자리가 상대방에게 보호받고 있는지 확인해 반격가능성이 있는 경우 공격한 기물의 가치만큼 해당 행동의 점수에서 차감

### 캐싱

- 연산 최적화를 위해 플레이어가 보이지 않도록 가상의 체스보드를 만들어 기물의 위치, 행동별 점수들을 저장, 변화하는 실제 게임 내 변화들만 반영해 연산 로직에 의한 점수들을


### 게임 시스템
* **Turn-Based Evaluation AI**: 실시간 재평가 연산 알고리즘을 통한 턴제 인공지능 판단 시스템
* **Local Persistence System**: `user://` 경로를 활용한 미디어 및 세이브 데이터의 독립적 로컬 관리

---

##  핵심 시스템 및 기능
### 1. 카드 기반 체스 전술 시스템
- **Action Token Mechanism**: 카드를 소모하여 특정 기물에 행동권(Action Token)을 부여하는 독창적인 체스 룰 구현
- **Dynamic Cost System**: 가변 코스트(`COST_X`) 지원으로 현재 남아있는 모든 마나를 소모하여 가변적 효과를 발동하는 데이터 주도 구조
### 2. Self-Designed Heuristic AI Engine (`AITestRunner`)
- **Weighted Score Evaluation**: 기물 가치, 위치 이점, 위협 가산점, 위험 감점 수식을 기반으로 한 알고리즘 판단
- **Real-Time Re-evaluation Loop**: 매 행동마다 체스판 캐시(`_build_cache`)를 동적으로 재스캔하여 변경된 경로와 위협을 즉시 반응 연산
### 3. FSM & Input Interception (`CardManager`)
- **FSM State Control**: `IDLE`, `DRAWING`, `PLAYING`, `VIEWING` 4단계 상태 제어
- **Race Condition Prevention**: 카드 드로우/사용 애니메이션 및 덱 조회 팝업 시 유저 입력을 완전 차단하여 입력 꼬임 및 Raycast 투과 방지
### 4. Data-Driven Deck Cycle Architecture (`DeckComponent`)
- **Runtime Pile Separation**: 원본 `.tres` 데이터 훼손 없이 runtime 독립 인스턴스 배열(`draw_pile`, `discard_pile`, `exhaust_pile`)을 셔플/순환
- **Dynamic Exhaust System**: 파괴/전멸된 기물 태그 감지 시, 해당 카드가 드로우될 때 자동으로 공중에서 소멸(`Exhaust`)하는 동적 규칙 적용
### 5. 3D/2D Hybrid Rendering & Smooth UX
- **SubViewport Integration**: 3D 체스 보드와 2D 카드 UI/UX 레이어를 시각적 격리 없이 매끄럽게 통합
- **Procedural Fan Hand Layout**: 손패 카드 개수에 따라 자동으로 호(Arc) 형상 부채꼴 정렬 및 부드러운 Tween 연출


## 기술 스택

### 프레임워크 및 언어
- **Godot Engine (v4.6.3)**: 3D/2D 복합 게임 씬 통합 관리 및 렌더링
- **Antigravity**: 
- **GDScript**: 객체지향 기반의 모듈화된 게임 로직 및 데이터 처리

---

### 아키텍쳐 및 디자인 패턴

* **컴포넌트 중심 아키텍처**
  * 개별 기능(이동, 카드 등)을 독립된 노드로 분리하여 코드 간 결합도를 최소화하고 재사용성 극대화
  * 연쇄적 오류를 최대한 방지하고 유지보수 및 수정 시 

* **유한 상태 머신 (FSM)**
  * 플레이어 조작, 턴 진행, 시스템 반응을 상태 단위로 통제하여 입력 충돌 및 예외 동작 원천 차단

* **데이터 주도 설계**
  * 데이터와 로직 스크립트를 철저히 분리하여 데이터 확장 및 밸런싱 편의성 확보

* **시그널 중심 전역 통신**
  * "Call Down, Signal Up" 원칙을 준수하여 노드 간의 직접적인 하드코딩 참조를 배제하고 안정적인 이벤트를 주고받음

---

### 🛠️ Development Tools
* **Version Control**: Git / GitHub
* **Environment**: VS Code (Godot Tools), Godot Engine Editor
