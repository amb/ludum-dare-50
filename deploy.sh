godot --no-window --export "HTML5" ./build/html5/index.html
godot --no-window --export "Linux/X11" ./build/linux/survivor.x86_64

butler push build/linux ambi/survivor:linux
butler push build/html5 ambi/survivor:html
