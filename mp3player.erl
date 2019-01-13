-module(mp3player).
-compile([export_all]).
-include_lib("wx/include/wx.hrl").




write() ->

    receive
        {play} ->
            io:format("\nplaying ~p \nVol: ~p Mute: ~p ~n", [get_curr_song(),get_vol(),is_mute()]),
            write();
        {pause} ->
            io:format("\npause ~p \nVol: ~p Mute: ~p ~n", [get_curr_song(),get_vol(),is_mute()]),
            write();
        {volume} ->
            io:format("\nVol: ~p Mute: ~p ~n", [get_vol(),is_mute()]),
            write()
    end.

  get_key_event(WritePid) ->

      receive
          {p} ->
              WritePid ! {play},
              get_key_event(WritePid);
          {s} ->
              WritePid ! {pause},
              get_key_event(WritePid);
          {n} ->
              play_next_song(WritePid),
              get_key_event(WritePid);
          {p} ->
              play_prev_song(WritePid),
              get_key_event(WritePid);
          {'+'} ->
              rise_vol(WritePid),
              get_key_event(WritePid);
          {'-'} ->
              lower_vol(WritePid),
              get_key_event(WritePid);
          {m} ->
              update_mute(WritePid),
              get_key_event(WritePid)
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
  Path = "/home/paulina/semestrV/basic_mp3_player/current_song.txt",
  file:write_file(Path, Title).

get_curr_song() ->
  Path = "/home/paulina/semestrV/basic_mp3_player/current_song.txt",
  Title = readlines(Path),
  Title.

update_all_songs(Title) ->
  Path = "/home/paulina/semestrV/basic_mp3_player/all_songs.txt",
  file:write_file(Path, "\n"++Title, [append]).

get_all_songs() ->
  Path = "/home/paulina/semestrV/basic_mp3_player/all_songs.txt",
  Songs = readlines(Path),
  string:lexemes(Songs,"\n").

search_next(Val, [Val, Next|_],_)-> Next;
search_next(Val, [_|T], L)-> search_next(Val, T,L);
search_next(_,[],[First|_])-> First.

search_prev(Val, [Val|T])-> lists:last(T);
search_prev(Val, [Prev, Val|_])-> Prev;
search_prev(Val, [_|T])-> search_prev(Val, T).

get_next_song() ->
  Songs = get_all_songs(),
  Next_song = search_next(get_curr_song(),Songs,Songs),
  Next_song.

get_prev_song() ->
  Songs = get_all_songs(),
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
  Path = "/home/paulina/semestrV/basic_mp3_player/speaker.txt",
  Speaker = readlines(Path),
  string:lexemes(Speaker,"\n").

is_mute() ->
  [IsMute|_] = get_speaker(),
  IsMute.

get_vol() ->
  [_,Vol_str|_] = get_speaker(),
  {Vol,_} = string:to_integer(Vol_str),
  Vol.

get_opposite_Mute(<<"T">>) -> "F";
get_opposite_Mute(<<"F">>) -> "T";
get_opposite_Mute(A) -> A.



update_mute(Pid) ->
  Path = "/home/paulina/semestrV/basic_mp3_player/speaker.txt",
  {ok, Content} = file:read_file(Path),
  [IsMute | Tail] = binary:split(Content, <<"\n">>),
  NewContent = [get_opposite_Mute(IsMute), <<"\n">> | Tail],
  file:write_file(Path, NewContent),
  Pid ! {volume}.

get_corr_vol(51) -> 50;
get_corr_vol(-1) -> 0;
get_corr_vol(Vol) -> Vol.

rise_vol(Pid) ->
  Path = "/home/paulina/semestrV/basic_mp3_player/speaker.txt",
  NewContent = is_mute()++"\n"++integer_to_list(get_corr_vol(get_vol()+1)),
  file:write_file(Path, NewContent),
  Pid ! {volume}.

lower_vol(Pid) ->
  Path = "/home/paulina/semestrV/basic_mp3_player/speaker.txt",
  NewContent = is_mute()++"\n"++integer_to_list(get_corr_vol(get_vol()-1)),
  file:write_file(Path, NewContent),
  Pid ! {volume}.


run() ->
    Pid2 = spawn(?MODULE, write, []),
    Pid2 ! {play},
    Pid2 ! {pause},
    play_next_song(Pid2),
    lower_vol(Pid2),

    %Pid3 = spawn(?MODULE, music, []),
    %Pid3 ! 'p',




    ok.
