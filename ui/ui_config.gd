class_name UiConfig
extends RefCounted
## UI 배치·크기·색 설정 모음. 디자인과 위치가 바뀌면 이 파일의 값만 고치면 되도록 모아 둔다.
## (화면 스크립트에는 가능한 한 숫자를 직접 쓰지 않는다)

# --- 화면 기준 해상도 (창 크기와 무관하게 이 크기 기준으로 배치 후 확대·축소) ---
const BASE_SIZE: Vector2i = Vector2i(1280, 720)

# --- 상단 바 (타이머·화면 이동) ---
const TOP_BAR_HEIGHT: int = 46
const TIMER_FONT_SIZE: int = 26
const TIMER_WARNING_SECONDS: float = 15.0

# --- 색 ---
const COLOR_BG_PANEL: Color = Color(0.1, 0.11, 0.15, 0.9)
const COLOR_SHOP_BG: Color = Color("2b3d3a")
const COLOR_BAR_BG: Color = Color("c3c7c9")
const COLOR_ACCENT: Color = Color("f2c14e")
const COLOR_DIM: Color = Color("9aa0b4")
const COLOR_SELL: Color = Color("e5483f")
const COLOR_REROLL: Color = Color("2fae6b")
const COLOR_BACK: Color = Color("f26b6b")
const COLOR_SELECTED: Color = Color("ffdd55")
const COLOR_TARGET: Color = Color("55e08a")
const COLOR_LOCKED: Color = Color(0.25, 0.25, 0.28)
const RARITY_COLORS: Array[Color] = [Color("aab4c8"), Color("6fd38c"), Color("6d8cff"), Color("ff9a3c")]

# --- 상점 카드 ---
const SHOP_CARD_SIZE: Vector2 = Vector2(150, 150)
const SHOP_ICON_SIZE: Vector2 = Vector2(86, 86)
const SHOP_ROW_GAP: int = 10
const SHOP_COLUMN_GAP: int = 8
## 왼쪽 상시 열(식량·성벽)과 나머지 사이 간격
const SHOP_FIXED_COLUMN_GAP: int = 28

# --- 주사위 위젯 (주사위 + 아래 동그란 인첸트 슬롯) ---
const DICE_ICON_SIZE: Vector2 = Vector2(64, 64)
const SLOT_RADIUS: float = 9.0
const SLOT_GAP: float = 4.0
## 주사위를 눌렀을 때 확대되는 슬롯
const SLOT_RADIUS_LARGE: float = 22.0

# --- 툴팁 ---
const TOOLTIP_OFFSET: Vector2 = Vector2(22, 18)
const TOOLTIP_MAX_WIDTH: int = 280


static func rarity_color(rarity: int) -> Color:
	return RARITY_COLORS[clampi(rarity, 0, RARITY_COLORS.size() - 1)]
