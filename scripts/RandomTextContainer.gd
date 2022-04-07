extends VBoxContainer

var my_labels = {}

func setText(label, value):
	var outputText = "%s: %s" % [label, str(value)]
	if not my_labels.has(label):
		var newLabel = Label.new()
		my_labels[label] = newLabel
		newLabel.text = outputText
		add_child(newLabel)
	else:
		my_labels[label].text = outputText
