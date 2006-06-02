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
          -N"fltk::Adjuster::Adjuster(fltk::Adjuster const&)" \
          -N"fltk::Valuator::Valuator(fltk::Valuator const&)" \
          -N"fltk::BarGroup::BarGroup(fltk::BarGroup const&)" \
          -N"fltk::Group::Group(fltk::Group const&)" \
          -N"fltk::HighlightBox::HighlightBox(fltk::HighlightBox const&)" \
          -N"fltk::FlatBox::FlatBox(fltk::FlatBox const&)" \
          -N"fltk::FrameBox::FrameBox(fltk::FrameBox const&)" \
          -N"fltk::Symbol::Symbol(char const*)" \
          -N"fltk::Button::Button(fltk::Button const&)" \
          -N"fltk::CheckButton::CheckButton(fltk::CheckButton const&)" \
          -N"fltk::Choice::Choice(fltk::Choice const&)" \
          -N"fltk::Menu::Menu(fltk::Menu const&)" \
          -N"fltk::Clock::Clock(fltk::Clock const&)" \
          -N"fltk::ClockOutput::ClockOutput(fltk::ClockOutput const&)" \
          -N"fltk::ColorChooser::ColorChooser(fltk::ColorChooser const&)" \
          -N"fltk::ccCellBox::ccCellBox(fltk::ccCellBox const&)" \
          -N"fltk::ccValueBox::ccValueBox(fltk::ccValueBox const&)" \
          -N"fltk::ccHueBox::ccHueBox(fltk::ccHueBox const&)" \
          -N"fltk::ColorChooser::h() const" \
          -N"fltk::ColorChooser::r() const" \
          -N"fltk::ColorChooser::b() const" \
          -N"fltk::ComboBox::ComboBox(fltk::ComboBox const&)" \
          -N"fltk::Input::Input(fltk::Input const&)" \
          -N"fltk::Widget::position(int, int)" \
          -N"fltk::CycleButton::CycleButton(fltk::CycleButton const&)" \
          -N"fltk::Dial::Dial(fltk::Dial const&)" \
          -N"fltk::Divider::Divider(fltk::Divider const&)" \
          -N"fltk::DoubleBufferWindow::DoubleBufferWindow(fltk::DoubleBufferWindow const&)" \
          -N"fltk::Window::Window(fltk::Window const&)" \
          -N"fltk::FileInput::FileInput(fltk::FileInput const&)" \
          -N"fltk::FileInput::text(char const*)" \
          -N"fltk::FileInput::text(char const*, int)" \
          -N"fltk::FillDial::FillDial(fltk::FillDial const&)" \
          -N"fltk::FillSlider::FillSlider(fltk::FillSlider const&)" \
          -N"fltk::Slider::Slider(fltk::Slider const&)" \
          -N"fltk::FloatInput::FloatInput(fltk::FloatInput const&)" \
          -N"fltk::NumericInput::NumericInput(fltk::NumericInput const&)" \
          -N"fltk::HighlightButton::HighlightButton(fltk::HighlightButton const&)" \
          -N"fltk::InputBrowser::InputBrowser(fltk::InputBrowser const&)" \
          -N"fltk::IntInput::IntInput(fltk::IntInput const&)" \
          -N"fltk::InvisibleBox::InvisibleBox(fltk::InvisibleBox const&)" \
          -N"fltk::ItemGroup::ItemGroup(fltk::ItemGroup const&)" \
          -N"fltk::ItemRadio::ItemRadio(fltk::ItemRadio const&)" \
          -N"fltk::ItemToggle::ItemToggle(fltk::ItemToggle const&)" \
          -N"fltk::Item::Item(fltk::Item const&)" \
          -N"fltk::Widget::type() const" \
          -N"fltk::LightButton::LightButton(fltk::LightButton const&)" \
          -N"fltk::LineDial::LineDial(fltk::LineDial const&)" \
          -N"fltk::MenuBar::MenuBar(fltk::MenuBar const&)" \
          -N"fltk::PopupMenu::PopupMenu(fltk::PopupMenu const&)" \
          -N"fltk::MenuWindow::MenuWindow(fltk::MenuWindow const&)" \
          -N"fltk::MultiLineInput::MultiLineInput(fltk::MultiLineInput const&)" \
          -N"fltk::MultiLineOutput::MultiLineOutput(fltk::MultiLineOutput const&)" \
          -N"fltk::Output::Output(fltk::Output const&)" \
          -N"fltk::PackedGroup::PackedGroup(fltk::PackedGroup const&)" \
          -N"fltk::ProgressBar::ProgressBar(fltk::ProgressBar const&)" \
          -N"fltk::RadioButton::RadioButton(fltk::RadioButton const&)" \
          -N"fltk::RadioLightButton::RadioLightButton(fltk::RadioLightButton const&)" \
          -N"fltk::RepeatButton::RepeatButton(fltk::RepeatButton const&)" \
          -N"fltk::ReturnButton::ReturnButton(fltk::ReturnButton const&)" \
          -N"fltk::Scrollbar::Scrollbar(fltk::Scrollbar const&)" \
          -N"fltk::Scrollbar::value()" \
          -N"fltk::SecretInput::SecretInput(fltk::SecretInput const&)" \
          -N"fltk::TabGroup::TabGroup(fltk::TabGroup const&)" \
          -N"fltk::ThumbWheel::ThumbWheel(fltk::ThumbWheel const&)" \
          -N"fltk::TiledGroup::TiledGroup(fltk::TiledGroup const&)" \
          -N"fltk::ToggleButton::ToggleButton(fltk::ToggleButton const&)" \
          -N"fltk::Tooltip::Tooltip(fltk::Tooltip const&)" \
          -N"fltk::WordwrapInput::WordwrapInput(fltk::WordwrapInput const&)" \
          -N"fltk::WordwrapOutput::WordwrapOutput(fltk::WordwrapOutput const&)" \
          -N"fltk::Scrollbar& fltk::Scrollbar::operator=(fltk::Scrollbar const&)" \
          -N"fltk::Browser::Browser(fltk::Browser const&)" \
          -N"fltk::MultiBrowser::MultiBrowser(fltk::MultiBrowser const&)" \
          -N"fltk::ScrollGroup::ScrollGroup(fltk::ScrollGroup const&)" \
          -N"fltk::Browser::focus_index() const" \
          -N"fltk::Browser::value(int)" \
          -N"fltk::ValueInput::ValueInput(fltk::ValueInput const&)" \
          -N"fltk::Image::Image(fltk::Image const&)" \
          -N"fltk::Image::Image(char const*)" \
          -N"fltk::Image::Image(int, int, char const*, char const* const*)" \
          -N"fltk::MultiImage::MultiImage(fltk::MultiImage const&)" \
          -N"fltk::pnmImage::pnmImage(fltk::pnmImage const&)" \
          -N"fltk::pngImage::pngImage(fltk::pngImage const&)" \
          -N"fltk::SharedImage::SharedImage(fltk::SharedImage const&)" \
          -N"fltk::jpegImage::jpegImage(fltk::jpegImage const&)" \
          -N"fltk::xpmFileImage::xpmFileImage(fltk::xpmFileImage const&)" \
          -N"fltk::bmpImage::bmpImage(fltk::bmpImage const&)" \
          -N"fltk::gifImage::gifImage(fltk::gifImage const&)" \
          -N"fltk::TiledImage::TiledImage(fltk::TiledImage const&)" \
          \
          -N"fltk::Input::maybe_do_callback()" \
          -N"fltk::end_group()" \
          \
          -N"fltk::image_filetypes" \
          -N"fltk::Menu::get_location(fltk::Widget*, int const*, int, int) const"
done
