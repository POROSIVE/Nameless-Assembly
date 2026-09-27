extends Node
class_name ItemIcon

func generate(item_id: String, color: Color) -> Texture2D:
	var size := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	
	var bg := color.darkened(0.55)
	img.fill(bg)
	_draw_rect_border(img, 2, 2, size - 3, color)
	
	if "powder" in item_id:
		_draw_circle(img, size / 2, size / 2 -2, 8, color)
	elif "ingot" in item_id:
		_draw_rect(img, 8, 8, 16, 14, color)
	elif  "wire" in item_id :
		_draw_line(img, 4, 16, 28, 16, 3, color)
	elif "resin" in item_id:
		_draw_triangle(img, 16, 6, 8, 26, 24, 26, color)
	elif "circuit" in item_id :
		_draw_rect(img, 6, 6, 20, 20, color)
	else:
		_draw_circle(img, size / 2, size / 2, 8, color)
		
	return ImageTexture.create_from_image(img) 
	
	
func _draw_circle(img, cx, cy, r, color):
	for y in range(int(cy - r), int(cy + r) + 1):
		for x in range(int(cx - r), int(cx + r) + 1):
			if (x - cx) * (x - cx) + (y-cy) * (y-cy) <= r * r:
				if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
					img.set_pixel(x, y, color)
			
func _draw_rect(img, x, y, w, h, color):
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and yy >= 0 and xx < img.get_width() and yy < img.get_height():
				img.set_pixel(xx, yy, color)
				
func _draw_rect_border(img, x, y, size, color):
	_draw_rect(img, x, y, size, 2, color)
	_draw_rect(img, x, y + size - 2,  size, 2, color)
	_draw_rect(img, x, y, 2, size, color)
	_draw_rect(img, x + size - 2, y, 2, size, color)
	
func _draw_line(img: Image, x1: int, y1: int, x2: int, y2: int, width: int, color: Color) -> void:
	var dx := int(abs(x2 - x1))
	var dy := int(abs(y2 - y1))
	var steps := int(max(dx, dy))
	for i in range(steps + 1):
		var t := float(i) /  float(max(steps, 1))
		var x := int(round(x1 + (x2 - x1) * t))
		var y := int(round(y1 + (y2 - y1) * t))
		for w in range(-width / 2, width / 2 + 1):
			for h in range(-width / 2, width / 2 + 1):
				var px := x + w
				var py := y + h
				if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
					img.set_pixel(px, py, color)

func _draw_triangle(img,x1, y1, x2, y2, x3, y3, color):
	for y in range(0,32):
		for x in range(0, 32):
			if _point_in_triangle(x, y, x1, y1, x2, y2, x3, y3):
				img.set_pixel(x, y, color)
func _point_in_triangle(px, py, x1, y1, x2, y2, x3, y3):
	var d1 := int(_sign(px, py, x1, y1, x2, y2))
	var d2 := int(_sign(px, py, x2, y2, x3, y3))
	var d3 := int(_sign(px, py, x3, y3, x1, y1))
	var has_neg := bool((d1 < 0) or (d2 < 0) or (d3 < 0))
	var has_pos := bool((d1 > 0) or (d2 > 0) or (d3 > 0))
	return not (has_neg and has_pos)
		
func _sign(px, py, x1,y1, x2, y2):
	return (px- x2) * (y1 - y2) - (x1 - x2) * (py - y2)
