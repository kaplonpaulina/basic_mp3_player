-module(mp3player).
-compile([export_all]).
-include_lib("wx/include/wx.hrl").

write() ->
    receive
        {play} ->
            {{Year,Month,Day},{Hour,Min,Sec}} = erlang:localtime(),
            Str = io_lib:format("\n\n -- log, date ~p:~p:~p ~p-~p-~p --\nplaying ~p \nPLaylist: ~p\nVol: ~p Mute: ~p ~n", [Hour,Min,Sec,Day,Month,Year,get_curr_song(),get_curr_playlist(),get_vol(),is_mute()]),
            append_log(Str),
            write();
        {pause} ->
            {{Year,Month,Day},{Hour,Min,Sec}} = erlang:localtime(),
            Str = io_lib:format("\n\n -- log, date ~p:~p:~p ~p-~p-~p --\npause ~p \nVol: ~p Mute: ~p ~n", [Hour,Min,Sec,Day,Month,Year,get_curr_song(),get_vol(),is_mute()]),
            append_log(Str),
            write();
        {volume} ->
            {{Year,Month,Day},{Hour,Min,Sec}} = erlang:localtime(),
            Str = io_lib:format("\n\n -- log, date ~p:~p:~p ~p-~p-~p --\nVol: ~p Mute: ~p ~n", [Hour,Min,Sec,Day,Month,Year,get_vol(),is_mute()]),
            append_log(Str),
            write()
    end.

append_log(Log) ->
  try
    [{_, HomePath}] = ets:lookup(paths, path),
    Path = filename:join(HomePath, "log.txt"),
    file:write_file(Path, Log, [append])
  catch
    Exception:Reason -> {caught, Exception, Reason},
    io:format("\nWyjatek: ~p\n",[Reason])
  end.


set_txt(State) ->
  try
  	timer:sleep(20),
  	Vol= io_lib:format("~p",[get_vol()]),
  	lists:flatten(Vol),
  	Mute= io_lib:format("~p",[is_mute()]),
  	lists:flatten(Mute),
  	[{_, T}] = ets:lookup(pids, value),
  	Text = State ++ ": " ++ get_curr_song() ++ "\nPlaylista: " ++ get_curr_playlist() ++ "\nGlosnosc: " ++ Vol ++ "\tWyciszenie: " ++ Mute ,
  	wxTextCtrl:setValue(T,Text)
  catch
    Exception:Reason -> {caught, Exception, Reason},
    io:format("\nWyjatek: ~p\n",[Reason])
  end.

end_of_song(Pid)->
	receive
		{next,false} -> Pid ! {next},
		end_of_song(Pid)
	end.

seconds(Pid,Paused)->
	receive
		{new}->
			Pid ! {new},
			seconds(Pid, false);
		{pause}->
			Pid ! {pause},
			seconds(Pid,true)
	after
		10000 ->
			Pid ! {next,Paused},
			seconds(Pid,Paused)
	end.



  get_event(WritePid) ->
		[{_, TimerPid}] = ets:lookup(pids, timerPid),
      receive
          {play} ->
              WritePid ! {play},
							TimerPid ! {new},
						  get_event(WritePid);
          {pause} ->
              WritePid ! {pause},
							TimerPid ! {pause},
              get_event(WritePid);
          {next} ->
              play_next_song(WritePid),
							TimerPid ! {new},
              get_event(WritePid);
					{prev} ->
	            play_prev_song(WritePid),
							TimerPid ! {new},
	            get_event(WritePid);
          {up} ->
              rise_vol(WritePid),
              get_event(WritePid);
          {down} ->
              lower_vol(WritePid),
              get_event(WritePid);
          {mute} ->
              update_mute(WritePid),
              get_event(WritePid);
					{change_playlist, Index} ->
							play_next_playlist(WritePid,Index),
							TimerPid ! {new},
							get_event(WritePid)
      end.

%music() ->
%     os:cmd("ffplay /home/paulina/semestrV/basic_mp3_player/m.mp3").

readlines(Path) ->
       {ok, Device} = file:open(Path, [read]),
       try get_all_lines(Device)
         after file:close(Device)
       end.

get_all_lines(Device) ->
       case io:get_line(Device, "") of
           eof  -> [];
           Line -> Line ++ get_all_lines(Device)
       end.

update_curr_song(Title) ->
  try
    [{_, HomePath}] = ets:lookup(paths, path),
    Path = filename:join(HomePath, "current_song.txt"),
    file:write_file(Path, Title)
  catch
    Exception:Reason -> {caught, Exception, Reason},
    io:format("\nWyjatek: ~p\n",[Reason]),
    io:format("llllllllllllllllllllllllllllllllllllllll")
  end.


get_curr_song() ->

  [{_, HomePath}] = ets:lookup(paths, path),
  Path = filename:join(HomePath, "current_song.txt"),
  Title = readlines(Path),
  case length(Title) of
    0 -> io:format("brak curr piosenki"),
        update_curr_playlist(0);
    _ -> Title
  end.

update_all_songs(Title) ->
  [{_, HomePath}] = ets:lookup(paths, path),
  Path = filename:join(HomePath, "all_songs.txt"),
  file:write_file(Path, "\n"++Title, [append]).

get_songs() ->
	Playlist = get_curr_playlist(),
  [{_, HomePath}] = ets:lookup(paths, path),
  Path = filename:join(HomePath, Playlist++".txt"),
  Songs = readlines(Path),
  string:lexemes(Songs,"\n").

get_all_playlists()->
  [{_, HomePath}] = ets:lookup(paths, path),
  Path = filename:join(HomePath,"playlists.txt"),
	Playlist = readlines(Path),
	string:lexemes(Playlist,"\n").

update_curr_playlist(Index)->
  [{_, HomePath}] = ets:lookup(paths, path),
  Path = filename:join(HomePath,"current_playlist.txt"),
	Playlists = get_all_playlists(),
	Playlist = lists:nth(Index+1, Playlists),
	file:write_file(Path, Playlist),
	Song = get_curr_song(),
  case length(get_songs()) of
    0  ->
      io:format("nie można odczytać pliku \n proba domyslnej playlisty \n"),
      timer:sleep(2000),
      file:write_file(Path, lists:nth(1, Playlists)),
      case length(get_songs()) of
        0  ->
          io:format("nie ma żadnych piosenek \n"),
          %timer:sleep(1000),
          halt();
        _ -> io:format("udalo sie pomyslnie zmienic plyliste")
      end;
    _ -> ok
  end,
  Songs = get_songs(),
	case lists:member(Song, Songs) of
		false ->
			[First|_] = Songs,
			update_curr_song(First);
		true ->  ok
	end.

get_curr_playlist()->
  [{_, HomePath}] = ets:lookup(paths, path),
  Path = filename:join(HomePath,"current_playlist.txt"),
  Playlist = readlines(Path),
  Playlist.

play_next_playlist(Pid,Index)->
	update_curr_playlist(Index),
	Pid ! {play}.


search_next(Val, [Val, Next|_],_)-> Next;
search_next(Val, [_|T], L)-> search_next(Val, T,L);
search_next(_,[],[First|_])-> First.

search_prev(Val, [Val|T])-> lists:last(T);
search_prev(Val, [Prev, Val|_])-> Prev;
search_prev(Val, [_|T])-> search_prev(Val, T).

get_next_song() ->
  Songs = get_songs(),
  Next_song = search_next(get_curr_song(),Songs,Songs),
  Next_song.

get_prev_song() ->
  Songs = get_songs(),
  Prev_song = search_prev(get_curr_song(),Songs),
  Prev_song.

play_next_song(Pid) ->
  timer:sleep(10),
  Song = get_next_song(),
  update_curr_song(Song),
  Pid ! {play}.

play_prev_song(Pid) ->
  timer:sleep(10),
  Song = get_prev_song(),
  update_curr_song(Song),
  Pid ! {play}.

get_speaker() ->
  [{_, HomePath}] = ets:lookup(paths, path),
  Path = filename:join(HomePath,"speaker.txt"),
  Speaker = readlines(Path),
  string:lexemes(Speaker,"\n").

is_mute() ->
  [IsMute|_] = get_speaker(),
  IsMute.

get_vol() ->
  [_,Vol_str|_] = get_speaker(),
  {Vol,_} = string:to_integer(Vol_str),
  if
    Vol < 0 -> throw(ujemna_wartosc_naglosnienia);
    Vol > 51 -> throw(przekroczona_maksymalna_wartosc_naglosnienia);
    true -> true
  end,
  Vol.

get_opposite_Mute(<<"T">>) -> "F";
get_opposite_Mute(<<"F">>) -> "T";
get_opposite_Mute(A) -> A.

update_mute(Pid) ->
  [{_, HomePath}] = ets:lookup(paths, path),
  Path = filename:join(HomePath,"speaker.txt"),
  {ok, Content} = file:read_file(Path),
  [IsMute | Tail] = binary:split(Content, <<"\n">>),
  NewContent = [get_opposite_Mute(IsMute), <<"\n">> | Tail],
  file:write_file(Path, NewContent),
  Pid ! {volume}.

get_corr_vol(51) -> 50;
get_corr_vol(-1) -> 0;
get_corr_vol(Vol) -> Vol.

rise_vol(Pid) ->
  try
    [{_, HomePath}] = ets:lookup(paths, path),
    Path = filename:join(HomePath,"speaker.txt"),
    NewContent = is_mute()++"\n"++integer_to_list(get_corr_vol(get_vol()+1)),
    file:write_file(Path, NewContent),
    Pid ! {volume}
  catch
    Exception:Reason -> {caught, Exception, Reason},
    io:format("\nWyjatek: ~p\n",[Reason])
  end.

lower_vol(Pid) ->
  try

    [{_, HomePath}] = ets:lookup(paths, path),
    Path = filename:join(HomePath, "speaker.txt"),
    NewContent = is_mute()++"\n"++integer_to_list(get_corr_vol(get_vol()-1)),
    file:write_file(Path, NewContent),
    Pid ! {volume}
  catch
    Exception:Reason -> {caught, Exception, Reason},
    io:format("\nWyjatek: ~p\n",[Reason])
  end.

lol() ->
  io:format(filename:dirname(code:which(?MODULE))).

init() ->
  HomePath = filename:dirname(code:which(?MODULE)),

  ets:new(paths, [named_table, protected, set, {keypos, 1}]),
  ets:insert(paths, {path, HomePath }),

	Path = HomePath,
	wx:new(),
	Frame = wxFrame:new(wx:null(), -1, "mp3player", [{size,{800,630}}]),
	Panel = wxPanel:new(Frame),
	wxPanel:setBackgroundStyle(Panel, ?wxBG_STYLE_CUSTOM),
	wxFrame:show(Frame),
	DC = wxWindowDC:new(Frame),
	Background = wxBitmap:new(filename:join(Path, "mp3.xpm")),
	wxDC:clear(DC),
	wxDC:drawBitmap(DC, Background, {0, 30}),
	TextBox = wxTextCtrl:new(Panel,-1,[{pos,{130,120}},{size,{440,60}},{style, ?wxTE_MULTILINE}]),
	wxTextCtrl:setValue(TextBox,"MP3 Player"),


	ets:new(pids, [named_table, protected, set, {keypos, 1}]),
	WritePid = spawn(?MODULE, write, []),
	GetEventPid = spawn(?MODULE, get_event, [WritePid]),
	EndOdSongPid = spawn(?MODULE,end_of_song,[GetEventPid]),
	TimerPid = spawn(?MODULE,seconds,[EndOdSongPid,true]),
	ets:insert(pids, {timerPid, TimerPid}),
	ets:insert(pids, {value, TextBox}),
  ets:insert(pids, {getEventPid, GetEventPid}),
  ets:insert(pids, {frame, Frame}),

  update_curr_playlist(0),

	run(GetEventPid, Panel, Frame).

button(Panel,GetEventPid) ->
	set_txt("Odtwarzanie"),
	Songs = get_songs(),
	ListSongs = wxListBox:new(Panel, -1, [{pos, {400,360}},{size, {120,100}},
		 {choices, Songs},
		 {style, ?wxLB_SINGLE}]),
	wxListBox:connect(ListSongs, command_listbox_doubleclicked, [{callback,
					fun(_, _) ->
		{_,[X]} = wxListBox:getSelections(ListSongs),
		update_curr_song(X),
		 GetEventPid ! {play},
		 timer:sleep(10),
     set_txt("Odtwarzanie")
							end
	}]),
	wxListBox:setToolTip(ListSongs, "Wszystkie piosenki wybranej playlisty").


run(GetEventPid, Panel, Frame) ->
		[{_, Path}] = ets:lookup(paths, path),
		PlayLogo = wxBitmap:new(filename:join(Path, "play-button.xpm")),
		PauseLogo = wxBitmap:new(filename:join(Path, "pause-symbol.xpm")),
		NextLogo = wxBitmap:new(filename:join(Path, "skip-track.xpm")),
		PrevLogo = wxBitmap:new(filename:join(Path, "previous-track.xpm")),
		UpLogo = wxBitmap:new(filename:join(Path, "volume-up.xpm")),
		DownLogo = wxBitmap:new(filename:join(Path, "volume-down.xpm")),
		MuteLogo = wxBitmap:new(filename:join(Path, "sound-mute.xpm")),
		ExitLogo = wxBitmap:new(filename:join(Path, "close.xpm")),

		PlayButton = wxBitmapButton:new(Panel, 12, PlayLogo, [{pos,{110,250}},{size, {60, 35}}]),
		PauseButton = wxBitmapButton:new(Panel, 13, PauseLogo, [{pos,{210,250}},{size, {35, 35}}]),
		NextButton = wxBitmapButton:new(Panel, 14, NextLogo, [{pos,{370,250}},{size, {35, 35}}]),
		PrevButton = wxBitmapButton:new(Panel, 15, PrevLogo, [{pos,{290,250}},{size, {35, 35}}]),
		UpButton = wxBitmapButton:new(Panel, 16, UpLogo, [{pos,{530,250}},{size, {35, 35}}]),
		DownButton = wxBitmapButton:new(Panel, 17, DownLogo, [{pos,{450,250}},{size, {35, 35}}]),
		MuteButton = wxBitmapButton:new(Panel, 18, MuteLogo, [{pos,{610,250}},{size, {35, 35}}]),
		ExitButton = wxBitmapButton:new(Panel, 19, ExitLogo, [{pos,{660,90}},{size, {25, 25}}]),

		wxBitmapButton:setToolTip(PlayButton, "Odtwarzaj"),
		wxBitmapButton:setToolTip(PauseButton, "Pauza"),
		wxBitmapButton:setToolTip(NextButton, "Nastepna piosenka"),
		wxBitmapButton:setToolTip(PrevButton, "Poprzednia piosenka"),
		wxBitmapButton:setToolTip(UpButton, "Podglosnij"),
		wxBitmapButton:setToolTip(DownButton, "Przycisz"),
		wxBitmapButton:setToolTip(MuteButton, "Wylacz/wlacz glos"),
		wxBitmapButton:setToolTip(ExitButton, "Zakoncz"),

		wxBitmapButton:connect(PlayButton, command_button_clicked, [{callback,
         fun(_,_) ->
					GetEventPid ! {play},
					set_txt("Odtwarzanie")
             end
         }]),
		wxBitmapButton:connect(PauseButton, command_button_clicked, [{callback,
        fun(_,_) ->
 					 GetEventPid ! {pause},
					 set_txt("Pauza")
            end
		     }]),
		 wxBitmapButton:connect(NextButton, command_button_clicked, [{callback,
		 fun(_,_) ->
				 GetEventPid ! {next},
				 set_txt("Odtwarzanie")
				 end
		 }]),
		 wxBitmapButton:connect(PrevButton, command_button_clicked, [{callback,
		         fun(_,_) ->
		  	GetEventPid ! {prev},
			set_txt("Odtwarzanie")
		             end
		 }]),
		 wxBitmapButton:connect(UpButton, command_button_clicked, [{callback,
		         fun(_,_) ->

		  	GetEventPid ! {up},
			set_txt("Odtwarzanie")
		             end
		 }]),
		 wxBitmapButton:connect(DownButton, command_button_clicked, [{callback,
		         fun(_,_) ->
		  	GetEventPid ! {down},
			set_txt("Odtwarzanie")
		             end
		 }]),
		 wxBitmapButton:connect(MuteButton, command_button_clicked, [{callback,
		         fun(_,_) ->
		  	GetEventPid ! {mute},
			set_txt("Odtwarzanie")
		             end
		 }]),
		 wxBitmapButton:connect(ExitButton, command_button_clicked, [{callback,
		         fun(_,_) ->
							 [{_, TimerPid}] = ets:lookup(pids, timerPid),
				exit(TimerPid,reason),
		  	wxFrame:destroy(Frame)
		             end
		 }]),

		Playlists=get_all_playlists(),
		ListPlaylist = wxListBox:new(Panel, -1, [{pos, {200,360}},{size, {100,100}},
			{choices, Playlists},
			{style, ?wxLB_SINGLE}]),

		wxListBox:setToolTip(ListPlaylist, "Wszystkie playlisty"),

		wxListBox:connect(ListPlaylist, command_listbox_doubleclicked, [{callback,
						fun(_, _) ->
			{_,[X]} = wxListBox:getSelections(ListPlaylist),
			GetEventPid ! {change_playlist, X},
			timer:sleep(10),
			button(Panel,GetEventPid)
								end
		}]).
