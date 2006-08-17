#!/bin/bash
export CXXFLAGS="$CXXFLAGS `fltk2-config --cxxflags`"

#rm -rf bcd/fltk2

# Unsupported:
# error (variadic functions)
# filename, dirent, FileBrowser, FileInput, FileChooser (untranslated dirent stuff)

for i in Adjuster AlignGroup ask BarGroup Box Browser Button CheckButton Choice Clock ColorChooser Color ComboBox Cursor CycleButton damage Dial Divider DoubleBufferWindow draw events file_chooser FileIcon FillDial FillSlider Flags FL_API FloatInput fltk_cairo FL_VERSION Font gl glut GlWindow Group HelpDialog HelpView HighlightButton Image InputBrowser Input IntInput InvisibleBox ItemGroup Item LabelType layout LightButton LineDial load_plugin math MenuBar MenuBuild Menu MenuWindow Monitor MultiBrowser MultiImage MultiLineInput MultiLineOutput NumericInput Output PackedGroup PixelType pnmImage PopupMenu Preferences ProgressBar RadioButton RadioItem RadioLightButton Rectangle RepeatButton ReturnButton rgbImage run Scrollbar ScrollGroup SecretInput ShapedWindow SharedImage show_colormap Slider StatusBarGroup string StringList Style StyleSet Symbol SystemMenuBar TabGroup TextBuffer TextDisplay TextEditor ThumbWheel TiledGroup TiledImage ToggleButton Tooltip types utf Valuator ValueInput ValueOutput ValueSlider visual Widget Window WizardGroup WordwrapInput WordwrapOutput xbmImage xpmImage
do
        echo $i
        
        ./bcdgen $1/${i}.h fltk2 -Ifltk/ -r \
          -N"fltk::GlutWindow::menu" \
          -N"fltk::HelpTarget::name" \
          -N"fltk::HelpLink::filename" \
          -N"fltk::HelpLink::name" \
          -N"fltk::HelpBlock::line" \
          -N"fltk::image_filetypes" \
          -N"fltk::Scrollbar::value()" \
          -N"fltk::Scrollbar::value(int, int, int, int)" \
          -N"fltk::Browser::focus_index() const" \
          -N"fltk::Browser::value() const" \
          -N"fltk::Browser::value(int)" \
          -N"fltk::ColorChooser::h() const" \
          -N"fltk::ColorChooser::r() const" \
          -N"fltk::ColorChooser::b() const" \
          -N"fltk::Input::position(int, int)" \
          -N"fltk::ComboBox::position(int, int)" \
          -N"fltk::HelpView::resize(int, int, int, int)" \
          -N"fltk::HelpView::textsize(int)" \
          -N"fltk::HelpView::textsize() const" \
          -N"fltk::Item::type() const" \
          -N"fltk::Window::backbuffer() const" \
          -N"fltk::end_group()" \
          -N"fltk::Browser::load(char const*)"
done
