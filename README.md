## 기술 스택

### 프레임워크 및 언어
- **Godot Engine (v4.6.3)**: 3D/2D 복합 게임 씬 통합 관리 및 렌더링
- **Antigravity**: 
- **GDScript**: 객체지향 기반의 모듈화된 게임 로직 및 데이터 처리

---

### 아키텍쳐 및 

* **컴포넌트 중심 아키텍처**
  * 개별 기능(이동, 카드 등)을 독립된 노드로 분리하여 코드 간 결합도를 최소화하고 재사용성 극대화
  * 연쇄적 오류를 최대한 방지하고 유지보수 및 수정 시 

* **유한 상태 머신 (FSM)**
  * 플레이어 조작, 턴 진행, 시스템 반응을 상태 단위로 통제하여 입력 충돌 및 예외 동작 원천 차단

* **데이터 주도 설계**
  * 데이터와 로직 스크립트를 철저히 분리하여 데이터 확장 및 밸런싱 편의성 확보

* **Decoupled Event-Driven Communication (시그널 중심 전역 통신)**
  * "Call Down, Signal Up" 원칙을 준수하여 노드 간의 직접적인 하드코딩 참조를 배제하고 안정적인 이벤트를 주고받음

---

### AI & Game Systems
* **Turn-Based Evaluation AI**: 실시간 재평가 연산 알고리즘을 통한 턴제 인공지능 판단 시스템
* **Local Persistence System**: `user://` 경로를 활용한 미디어 및 세이브 데이터의 독립적 로컬 관리

---

### 🛠️ Development Tools
* **Version Control**: Git / GitHub
* **Environment**: VS Code (Godot Tools), Godot Engine Editor
