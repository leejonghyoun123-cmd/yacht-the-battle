class_name BarracksCopierItem
extends UserItemData
## 병영 복사기: 전투 시작 시 인원이 가장 적은 중첩칸에 가장 많은 중첩칸의 30%를 임시 증원 (영구 누적 없음)

@export var ratio: float = 0.3


func modify_packets(_item: ItemInstance, packets: Array[SpawnPacket]) -> void:
	var low: SpawnPacket = null
	var high: SpawnPacket = null
	for p: SpawnPacket in packets:
		if p.is_consumable:
			continue
		if low == null or p.total_count < low.total_count:
			low = p
		if high == null or p.total_count > high.total_count:
			high = p
	if low == null or high == null or low == high:
		return
	var extra: int = int(floorf(float(high.total_count) * ratio))
	low.total_count = FixedNum.add(low.total_count, extra)
	low.temp_count = FixedNum.add(low.temp_count, extra)
