#!/bin/sh -

if xdo id -a "$PANEL_NAME" > /dev/null
then
	printf "%s\n" "The panel is already running." >&2
	exit 1
fi

trap 'trap - TERM; kill 0' INT TERM QUIT EXIT

if [ -f "$HOME/.colours" ]
then
    . "$HOME/.colours"
else
    printf %s\\n "Colours file not found"
    exit 1
fi

[ -e "$PANEL_FIFO" ] && rm "$PANEL_FIFO"
mkfifo -m 0600 "$PANEL_FIFO"

bspc subscribe report > "$PANEL_FIFO" &
xtitle -sf 'T%s\n' > "$PANEL_FIFO" &
when -i1 -sf 'S%a %H:%M %Y-%m-%d' > "$PANEL_FIFO" &

panel_bar() {
    num_mon=$(bspc query -M | wc -l)

    while read -r line ; do
        case $line in
            S*)
                # sys output
                sys="%{F$COLOR_SYS_FG}%{B$COLOR_SYS_BG} ${line#?} %{F- B-}"
                ;;
            T*)
                # xtitle output
                title="%{F$COLOR_TITLE_FG}%{B$COLOR_TITLE_BG} ${line#?} %{B- F-}"
                ;;
            W*)
                # bspwm's state
                wm=
                IFS=':'
                set -- ${line#?}
                while [ $# -gt 0 ] ; do
                    item=$1
                    name=${item#?}
                    case $item in
                        [mM]*)
                            case $item in
                                m*)
                                    # monitor
                                    FG=$COLOR_MONITOR_FG
                                    BG=$COLOR_MONITOR_BG
                                    on_focused_monitor=
                                    ;;
                                M*)
                                    # focused monitor
                                    FG=$COLOR_FOCUSED_MONITOR_FG
                                    BG=$COLOR_FOCUSED_MONITOR_BG
                                    on_focused_monitor=1
                                    ;;
                            esac
                            [ $num_mon -lt 2 ] && shift && continue
                            wm="${wm}%{F${FG}}%{B${BG}}%{A:bspc monitor -f ${name}:} ${name} %{A}%{B- F-}"
                            ;;
                        [fFoOuU]*)
                            case $item in
                                f*)
                                    # free desktop
                                    FG=$COLOR_FREE_FG
                                    BG=$COLOR_FREE_BG
                                    UL=$BG
                                    ;;
                                F*)
                                    if [ "$on_focused_monitor" ] ; then
                                        # focused free desktop
                                        FG=$COLOR_FOCUSED_FREE_FG
                                        BG=$COLOR_FOCUSED_FREE_BG
                                        UL=$BG
                                    else
                                        # active free desktop
                                        FG=$COLOR_FREE_FG
                                        BG=$COLOR_FREE_BG
                                        UL=$COLOR_FOCUSED_FREE_BG
                                    fi
                                    ;;
                                o*)
                                    # occupied desktop
                                    FG=$COLOR_OCCUPIED_FG
                                    BG=$COLOR_OCCUPIED_BG
                                    UL=$BG
                                    ;;
                                O*)
                                    if [ "$on_focused_monitor" ] ; then
                                        # focused occupied desktop
                                        FG=$COLOR_FOCUSED_OCCUPIED_FG
                                        BG=$COLOR_FOCUSED_OCCUPIED_BG
                                        UL=$BG
                                    else
                                        # active occupied desktop
                                        FG=$COLOR_OCCUPIED_FG
                                        BG=$COLOR_OCCUPIED_BG
                                        UL=$COLOR_FOCUSED_OCCUPIED_BG
                                    fi
                                    ;;
                                u*)
                                    # urgent desktop
                                    FG=$COLOR_URGENT_FG
                                    BG=$COLOR_URGENT_BG
                                    UL=$BG
                                    ;;
                                U*)
                                    if [ "$on_focused_monitor" ] ; then
                                        # focused urgent desktop
                                        FG=$COLOR_FOCUSED_URGENT_FG
                                        BG=$COLOR_FOCUSED_URGENT_BG
                                        UL=$BG
                                    else
                                        # active urgent desktop
                                        FG=$COLOR_URGENT_FG
                                        BG=$COLOR_URGENT_BG
                                        UL=$COLOR_FOCUSED_URGENT_BG
                                    fi
                                    ;;
                            esac
                            wm="${wm}%{F${FG}}%{B${BG}}%{U${UL}}%{+u}%{A:bspc desktop -f ${name}:} ${name} %{A}%{B- F-}%{-u}"
                            ;;
                        [LTG]*)
                            # layout, state and flags
                            wm="${wm}%{F$COLOR_STATE_FG}%{B$COLOR_STATE_BG} ${name} %{B- F-}"
                            ;;
                    esac
                    shift
                done
                ;;
        esac
        printf "%s\n" "%{l}${wm}%{c}${title}%{r}${sys}"
    done
}

panel_bar < "$PANEL_FIFO" | lemonbar -n "$PANEL_NAME" -g "$PANEL_GEOM" \
                                     -f "$PANEL_FONT" -F "$COLOR_FORE" \
                                     -B "$COLOR_BACK" | sh &

wid=$(xdo id -m -a "$PANEL_NAME")
xdo above -t "$(xdo id -N Bspwm -n root | sort | head -n 1)" "$wid"

wait
