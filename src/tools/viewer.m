function h=viewer(image_stack)
% Extremely lightweight, hotkey driven image viewer

    if nargin<1
        image_stack=hu(read_disp_recon_512('get'));
    end

    % Precalculate some stuff
    scrnsize=get(groot,'ScreenSize');
    middle=[scrnsize(3)/2,scrnsize(4)/2];
    width=size(image_stack,2);
    height=size(image_stack,1);
    img_1=image_stack(:,:,1);
    fig_pos=j_PositionVectorConvert([middle(1) middle(2) width height],'c->m');

    % Draw GUI
    %handles.fig=figure('ToolBar','none','MenuBar','none','position',fig_pos);
    handles.fig = figure('position',fig_pos);    
    h=handles.fig;
    fig_pos=get(handles.fig,'position');
    handles.axes=axes('position',[0 0 1 1],'parent',handles.fig);
    addToolbarExplorationButtons(handles.fig);
    handles.axes.Toolbar.Visible = 'off';

    % Disable the disabling of user callbacks
    hManager = uigetmodemanager(handles.fig);
    disp(hManager);
    try
        set(hManager.WindowListenerHandles, 'Enable', 'off');  % HG1
    catch
        [hManager.WindowListenerHandles.Enabled] = deal(false);  % HG2
    end
    
    % Set Callbacks
    set(handles.fig,'WindowKeyPressFcn',[]);
    set(handles.fig,'KeyPressFcn',@keypress_callback);
    set(handles.fig,'WindowScrollWheelFcn',@scroll_fcn);

    %Set default variables
    handles.curr_image=1;
    handles.image_stack=image_stack;
    handles.clims=[min(img_1(:)) max(img_1(:))];
    handles.flags.isplaying=false;
    handles.play_speed=1;
    handles.previous_save_location=pwd;
    handles.zoom=zoom;
    handles.flags.zoom=false;
    handles.counter=annotation('textbox',[0.02 0.02 .25 .1],'String',sprintf('%i/%i',handles.curr_image,size(handles.image_stack,3)),'backgroundcolor','black','color','white','facealpha',0,'edgecolor','none');

    handles.img = imshow(handles.image_stack(:,:,handles.curr_image),handles.clims,'parent',handles.axes);

    guidata(handles.fig,handles);

    update(handles.fig);

end

function keypress_callback(hObject,eventdata)
    handles=guidata(hObject);

    % base codes
    if isempty(eventdata.Modifier)
        switch eventdata.Key
          case 'd'
            r=j_imellipse('1',handles.axes);
            %r.addSecondaryPositionCallback(@wed_update)
            w=j_wed(handles.image_stack,(500/512)^2,r);
            disp(w)
            %figure;
            plot(w);
            assignin('base','w',w);
          case 'e' % drop elliptical roi
            j_imellipse('1',handles.axes);            
          case 'j' % jump to particular image number
            jump_to_image();
          case 'p' % save current image at current W/L as PNG
            save_curr_image();  
          case 'r' % drop rectangular roi
            j_imrect('1',handles.axes);
          case 'w' % access window level
            set_contrast();
          case 's'
            answer=inputdlg('Enter a variable name:');
            assignin('base',answer{1},handles.image_stack);
          case 'z'
            toggle_zoom();              
          case 'space' % play images as movie
            toggle_playing();
            play();
          case 'equal'
            handles.play_speed=handles.play_speed+0.5;
            guidata(hObject,handles);
          case 'hyphen'
            handles.play_speed=max(0.5,handles.play_speed-0.5);
            guidata(hObject,handles);
          case 'rightarrow' % next image
            next_image();
          case 'leftarrow' % previous image
            prev_image();


        end
    elseif isequal(eventdata.Modifier{1},'control')
        % control codes
        switch eventdata.Key
          case 'q' % quit/close
            delete(handles.fig)
          case 'w' % quit/close
            delete(handles.fig);
          case 'f' % next image (emacs)
            next_image();
          case 'b' % previous image (emacs)
            prev_image();
        end
    elseif isequal(eventdata.Modifier{1},'shift')
        switch eventdata.Key
          case 'space'
            toggle_playing();
            rewind();
          case 'w'
            set_manual_wl();
        end     
    else
        
    end

    %eventdata

    function set_contrast()
        j_window_level(handles.image_stack(:,:,handles.curr_image),handles.axes);
    end

    function set_manual_wl()
        answer=inputdlg({'Window:','Level:'});
        if isempty(answer)
            return;
        end

        window=str2double(answer{1});
        level =str2double(answer{2});
        
        if isnan(window)||isnan(level)
            return;
        end
        
        set(handles.axes,'clim',wl2clim([window level]));
        
        handles.clims=get(handles.axes,'clim');
        guidata(handles.fig,handles);
    end

    function save_curr_image()
        [e,fullpath]=j_UIPutFile(handles.previous_save_location,{'*.png'},'Save current image');
        if e~=0
            return
        end
        clims=get(handles.axes,'clim')
        
        save_mat_img(handles.image_stack(:,:,handles.curr_image),clims,fullpath);
        [handles.previous_save_location,~,~]=fileparts(fullpath);
        guidata(handles.fig,handles);
    end
    
    function next_image()
        handles.curr_image=min(size(handles.image_stack,3),handles.curr_image+1);
        guidata(handles.fig,handles);
        update(handles.fig);
    end

    function prev_image()
        handles.curr_image=max(1,handles.curr_image-1);
        guidata(handles.fig,handles);
        update(handles.fig);        
    end

    function jump_to_image()
        answer=inputdlg('Jump to image:');
        if isempty(answer)
            return;
        end
        
        answer=round(str2double(answer{1}));
        
        if isnan(answer)
            return;
        end
           
        if (answer>=1)&&(answer<=size(handles.image_stack,3))
            handles.curr_image=answer;
        else
            return;
        end

        guidata(handles.fig,handles);
        
        update(handles.fig);
    end
        
    function toggle_playing()
        handles.flags.isplaying=logical(1-handles.flags.isplaying);
        guidata(handles.fig,handles);
    end

    function toggle_zoom()
        handles.flags.zoom=logical(1-handles.flags.zoom);
        guidata(handles.fig,handles);
        if handles.flags.zoom
            handles.zoom.Enable='on';
            disp('zoom on');
        else
            zoom('off');
            disp('zoom off');
        end                
    end 

    function play()
        while handles.flags.isplaying
            if handles.curr_image==size(handles.image_stack,3)
                toggle_playing();
            end            
            next_image();
            pause(0.0417/handles.play_speed);
            handles=guidata(handles.fig);
        end 
    end

    function rewind()
        while handles.flags.isplaying
            if handles.curr_image==1
                toggle_playing();
            end
            prev_image();
            pause(0.0417/handles.play_speed);
            handles=guidata(handles.fig);
        end
    end
    
end

function scroll_fcn(hObject,eventdata)

    handles=guidata(hObject);

    amt=eventdata.VerticalScrollCount;

    if amt>0
        handles.curr_image=min(size(handles.image_stack,3),handles.curr_image+1);
    else
        handles.curr_image=max(1,handles.curr_image-1);
    end

    guidata(hObject,handles);
    update(handles.fig);
    
end

function update(fig)
    handles=guidata(fig);
    set(handles.img,'cdata',handles.image_stack(:,:,handles.curr_image));
    %imshow(handles.image_stack(:,:,handles.curr_image),handles.clims,'Parent',handles.axes);
    set(handles.counter,'string',sprintf('%i/%i',handles.curr_image,size(handles.image_stack,3)));
    drawnow;
end