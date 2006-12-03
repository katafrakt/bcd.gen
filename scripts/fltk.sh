#!/bin/bash
export CXXFLAGS="$CXXFLAGS `fltk-config --cxxflags`"

rm -rf bcd/fltk

# Unsupported:
# Fl_FormsBitmap, Fl_FormsPixmap (Derive from Fl_Widget without #including it)
# Fl_Input_Choice (mutliple derivations without #includes)
# Fl_Multi_Label, fl_show_colormap (syntax errors)
# forms, gl_draw, glut (bad dependencies)

for i in Enumerations Fl_Adjuster fl_ask Fl_Bitmap Fl_BMP_Image Fl_Box Fl_Browser_ Fl_Browser Fl_Button Fl_Chart Fl_Check_Browser Fl_Check_Button Fl_Choice Fl_Clock Fl_Color_Chooser Fl_Counter Fl_Dial Fl_Double_Window fl_draw Fl_Export Fl_File_Browser Fl_File_Chooser Fl_File_Icon Fl_File_Input Fl_Fill_Dial Fl_Fill_Slider Fl_Float_Input Fl_Free Fl_GIF_Image Fl_Gl_Window Fl_Group Fl Fl_Help_Dialog Fl_Help_View Fl_Hold_Browser Fl_Hor_Fill_Slider Fl_Hor_Nice_Slider Fl_Hor_Slider Fl_Hor_Value_Slider Fl_Image Fl_Input_ Fl_Input Fl_Int_Input Fl_JPEG_Image Fl_Light_Button Fl_Line_Dial Fl_Menu_Bar Fl_Menu_Button Fl_Menu_ Fl_Menu Fl_Menu_Window fl_message Fl_Multi_Browser Fl_Multiline_Input Fl_Multiline_Output Fl_Nice_Slider Fl_Object Fl_Output Fl_Overlay_Window Fl_Pack Fl_Pixmap Fl_PNG_Image Fl_PNM_Image Fl_Positioner Fl_Preferences Fl_Progress Fl_Radio_Button Fl_Radio_Light_Button Fl_Radio_Round_Button Fl_Repeat_Button Fl_Return_Button Fl_Roller Fl_Round_Button Fl_Round_Clock Fl_Scrollbar Fl_Scroll Fl_Secret_Input Fl_Select_Browser Fl_Shared_Image fl_show_input Fl_Simple_Counter Fl_Single_Window Fl_Slider Fl_Spinner Fl_Sys_Menu_Bar Fl_Tabs Fl_Text_Buffer Fl_Text_Display Fl_Text_Editor Fl_Tiled_Image Fl_Tile Fl_Timer Fl_Toggle_Button Fl_Toggle_Light_Button Fl_Toggle_Round_Button Fl_Tooltip Fl_Valuator Fl_Value_Input Fl_Value_Output Fl_Value_Slider Fl_Widget Fl_Window Fl_Wizard Fl_XBM_Image Fl_XPM_Image
do
        echo $i
        
        ./bcdgen $1/${i}.H fltk -IFL/ -r -E -P \
          -N"Fl_Scrollbar::value()" \
          -N"Fl_Menu_::test_shortcut()" \
          -N"Fl_Input_::position(int, int)" \
          -N"Fl::atclose" \
          -N"Fl::idle" \
          -N"Fl_Window::current()" \
          -N"Fl_Single_Window::make_current()" \
          -N"Fl::warning" \
          -N"Fl::error" \
          -N"Fl::fatal" \
          -N"Fl::set_abort(void (*)(char const*, ...))" \
          -N"FL_CHART_ENTRY::str" \
          -N"Fl_Help_Target::name" \
          -N"Fl_Help_Link::filename" \
          -N"Fl_Help_Link::name" \
          -N"Fl_Help_Block::line" \
          -N"Fl::gl_visual(int, int*)" \
          -N"Fl::has_check(void (*)(void*), void*)" \
          -N"Fl::set_labeltype(Fl_Labeltype, Fl_Labeltype)" \
          -N"Fl::lock()" \
          -N"Fl::unlock()" \
          -N"Fl::awake(void*)" \
          -N"Fl::thread_message()" \
          -N"Fl_Group::forms_end()"
done

# Needs dirent
echo filename
./bcdgen $1/filename.H fltk -IFL/ -r -E -P -Fstd.c.dirent

# Weird dual-definition
echo Fl_Menu_Item
./bcdgen $1/Fl_Menu_Item.H fltk -IFL/ -r -E -P \
  -N"fl_old_shortcut(char const*)"
