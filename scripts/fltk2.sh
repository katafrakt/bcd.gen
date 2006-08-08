#!/bin/bash
export CXXFLAGS="$CXXFLAGS `fltk2-config --cxxflags`"

rm -rf bcd/fltk2

# Unsupported:
# AlignGroup (align is a keyword in D)
# filename, dirent (totally different from the handling in D, has major collisions)
# error (variadic functions)
# FileBrowser, file_chooser, FileChooser (see filename, dirent)
# HelpView, HelpDialog (array support isn't stable yet)
# LabelType (array support isn't stable yet)
# Preferences (variatic functions)
# TextDisplay (not sure why this doesn't work :( )

for i in \
FL_API Flags Color Style Rectangle Widget Valuator Adjuster \
Group BarGroup \
PixelType Symbol Box \
Slider Scrollbar Menu Browser \
Button \
CheckButton \
Choice \
Clock \
ColorChooser \
Input ComboBox \
Cursor \
CycleButton \
damage \
Dial \
Divider \
Window DoubleBufferWindow \
draw \
events \
FileIcon \
FileInput \
FillDial \
FillSlider \
NumericInput FloatInput \
FL_VERSION \
Font \
HighlightButton \
types Image \
InputBrowser \
IntInput \
InvisibleBox \
ItemGroup \
Item \
layout \
LightButton \
LineDial \
load_plugin \
math \
MenuBar \
PopupMenu MenuBuild \
MenuWindow \
Monitor \
MultiBrowser \
MultiImage \
MultiLineInput \
Output MultiLineOutput \
PackedGroup \
ProgressBar \
RadioButton \
RadioItem \
RadioLightButton \
RepeatButton \
ReturnButton \
run \
ScrollGroup \
SecretInput \
SharedImage \
show_colormap \
StringList \
StyleSet \
TabGroup \
TextBuffer \
ThumbWheel \
TiledGroup \
TiledImage \
ToggleButton \
Tooltip \
utf \
ValueInput \
visual \
WordwrapInput \
WordwrapOutput
do
        echo $i
        
        ./bcdgen $1/${i}.h fltk2 -Ifltk/ \
          -N"fltk::Symbol::Symbol(char const*)" \
          -N"fltk::ColorChooser::h() const" \
          -N"fltk::ColorChooser::r() const" \
          -N"fltk::ColorChooser::b() const" \
          -N"fltk::Widget::position(int, int)" \
          -N"fltk::FileInput::text(char const*)" \
          -N"fltk::FileInput::text(char const*, int)" \
          -N"fltk::Widget::type() const" \
          -N"fltk::Scrollbar::value()" \
          -N"fltk::Browser::focus_index() const" \
          -N"fltk::Browser::value(int)" \
          -N"fltk::Image::Image(char const*)" \
          -N"fltk::Image::Image(int, int, char const*, char const* const*)" \
          \
          -N"fltk::Input::maybe_do_callback()" \
          -N"fltk::end_group()" \
          \
          -N"fltk::image_filetypes" \
          -N"fltk::Menu::get_location(fltk::Widget*, int const*, int, int) const" \
          \
          -N"fltk::Window::backbuffer() const"
done
