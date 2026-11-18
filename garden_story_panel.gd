extends VBoxContainer
var stories: RichTextLabel
var key:=""
func _ready() -> void:
 var heading:=Label.new();heading.text="Garden discoveries";add_child(heading)
 stories=RichTextLabel.new();stories.custom_minimum_size=Vector2(850,270);stories.bbcode_enabled=false;stories.scroll_active=true;add_child(stories)

func present(data: Dictionary) -> void:
 var entries: Array=data.get("entries",[]);var signature:=str(data)
 if signature==key:return
 key=signature
 var lines: Array[String]=[]
 for entry in entries.slice(maxi(0,entries.size()-12)):
  lines.append(str(entry.name)+"\n"+str(entry.description)+"\n"+str(entry.hint))
 stories.text="\n\n".join(lines) if not lines.is_empty() else "No discoveries yet. Bring seeds home and identify them at the Altar."
