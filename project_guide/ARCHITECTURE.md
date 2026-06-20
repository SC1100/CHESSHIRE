##ARCHITECTURE

Entity - (게임 규칙, 기물, 행위 로직 관리)
 ├─ Components
 └─ Systems

Card System - (카드 코스트, 키워드, 플레이어 덱 관리)
 ├─ Card Data
 ├─ Card Effect
 └─ Card Manager 

Battle System (전투 루프 관리)
 ├─ Turn Manager
 ├─ Board Manager
 └─ AI Manager

# [범용] 고도(Godot) 엔진 아키텍처 및 철학 규칙

## 1. 핵심 원칙 (The Core Laws)
- **컴포넌트 중심 (Composition)**: 모든 기능(이동, 체력, 상호작용 등)은 거대한 단일 스크립트가 아닌, 독립적인 노드(Component)로 쪼개어 조립한다.
- **결합도 최소화 (Decoupling)**: 한 스크립트가 다른 노드의 트리 경로(Node Path)를 직접 하드코딩하여 참조하지 않는다.
- **데이터 주도 설계 (Data-Driven Design) 및 하드코딩 배제**: 
  - 컴포넌트 내부에는 로직(빈 껍데기)만 구현하며, 속도, 데미지, 체력 같은 특정 수치(Magic Number)를 절대 코드 내부에 하드코딩하지 않는다.
  - **의존성 주입 (Dependency Injection)**: 모든 수치 데이터는 외부(`.tres` Resource 파일 또는 인스펙터의 `@export` 변수)에서 주입받아 작동하는 범용적인 플러그인 구조로 작성한다.

## 2. 로직 제어 및 통신 (Control & Communication)
- **위로는 시그널, 아래로는 함수 (Call down, Signal up)**: 
  - 자식 노드가 부모에게 상태 변화를 알릴 때는 반드시 `signal`을 방출(Emit)한다.
  - 부모가 자식에게 명령할 때는 직접 함수(Function)를 호출한다.
- **유한 상태 머신 (FSM) 필수 적용**: 플레이어 및 주요 객체의 행동(대기, 이동, 컷신 등)은 FSM 패턴으로 철저히 통제하여 입력 충돌이나 꼬임 현상을 원천 차단한다.
- **전역 통신**: 씬(Scene)이 달라도 공유해야 하는 코어 시스템 상태는 `Global.gd` (Singleton)를 통해 관리하되, 무분별한 남용을 금지한다.

## 3. 구조 및 명명 규칙 (Structure & Naming Conventions)
- **객관적이고 명확한 명명**: 변수명, 클래스명, 주석에는 미화된 단어(Euphemism)나 모호한 표현을 엄격히 금지한다. 생명체, 사물, 시스템의 본질과 기획자의 철학을 가장 객관적이고 무겁게 나타내는 단어만을 직관적으로 사용한다.
- **컴포넌트 파일명**: `[역할]Component.gd` (예: `MovementComponent.gd`, `HealthComponent.gd`)
- **폴더 구조 표준**: 
  - `res://scenes/components/` : 범용 부품 스크립트 (순수 로직)
  - `res://resources/data/` : 데이터 리소스 파일 (.tres)

## 4. 파일 입출력 및 세이브 (File I/O & Privacy)
- **로컬 독립성 및 프라이버시 보장**: 게임 내 세이브 데이터나 플레이어의 개인적인 로컬 미디어(사진, 영상 등)를 다룰 때는 외부 서버 통신을 배제하고 오직 `user://` 경로를 통한 로컬 처리만 수행한다.
- **단일 백업 구조**: 세이브 파일은 플레이어가 개인적으로 소장하거나 외부로 쉽게 백업(Export/Import)할 수 있도록 독립적이고 통합된 파일 구조로 설계한다.