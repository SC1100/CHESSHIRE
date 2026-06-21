extends Resource
class_name PieceData

enum Type { PAWN, KNIGHT, BISHOP, ROOK, QUEEN, KING }
enum Team { WHITE, BLACK }

@export var piece_name: String = "Pawn"
@export var type: Type = Type.PAWN
@export var team: Team = Team.WHITE

## 추후 여기에 이동 가능한 패턴(예: 대각선, 전진 등) 데이터를 추가할 예정입니다.
