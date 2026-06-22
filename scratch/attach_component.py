import os
import glob

piece_dir = r"d:\PJ_CH\Asset\ChessSet\Piece"
files = glob.glob(os.path.join(piece_dir, "*.tscn"))

for file_path in files:
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    if "GridDetectorComponent" in content:
        print(f"Already attached: {os.path.basename(file_path)}")
        continue
        
    # Find the last ext_resource id to create a unique one
    import re
    ext_resources = re.findall(r'\[ext_resource .*?id="([^"]+)"\]', content)
    # just use a hardcoded unique ID
    script_id = "grid_detector_script"
    
    # Insert ext_resource after the first [ext_resource ...] or [gd_scene ...]
    lines = content.split('\n')
    insert_idx = 1
    for i, line in enumerate(lines):
        if line.startswith("[ext_resource"):
            insert_idx = i + 1
    
    ext_resource_line = f'[ext_resource type="Script" path="res://scenes/components/GridDetectorComponent.gd" id="{script_id}"]'
    lines.insert(insert_idx, ext_resource_line)
    
    # Append node at the end
    node_lines = f'''
[node name="GridDetectorComponent" type="RayCast3D" parent="."]
script = ExtResource("{script_id}")
'''
    lines.append(node_lines)
    
    with open(file_path, "w", encoding="utf-8") as f:
        f.write('\n'.join(lines))
    print(f"Attached to: {os.path.basename(file_path)}")
