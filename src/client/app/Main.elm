module Main exposing (..)

import Char
import Html exposing (Html, br, button, div, text)
import Html.Attributes exposing (style, tabindex)
import Html.Events exposing (onClick)
import Time exposing (Time, millisecond)
import WebSocket
import Json.Decode as Json


tau : Float
tau =
    2 * pi


main : Program Flags Model Msg
main =
    Html.programWithFlags
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- MODEL


type alias ActiveGame =
    { leftY : Int, rightY : Int, ballX : Float, ballY : Float, ballDir : Float, ballSpeed : Int, waitForBallUpdate : Bool }


type Game
    = Active ActiveGame
    | Pending
    | GameOver Bool


type alias Model =
    { game : Game
    , wsserver : String
    }


type alias Flags =
    { wsserver : String }


init : Flags -> ( Model, Cmd Msg )
init flags =
    -- ( Active (ActiveModel 0 0 30 30 (0.1 * tau) 5), Cmd.none )
    ( Model Pending flags.wsserver, Cmd.none )


type WSMsg
    = BatUpdate Int
    | BallUpdate Float Float Float Int
    | GameStart
    | GameStop
    | Miss


encode : WSMsg -> String
encode wsMsg =
    let
        list =
            case wsMsg of
                GameStart ->
                    [ 101 ]

                GameStop ->
                    [ 102 ]

                Miss ->
                    [ 103 ]

                BatUpdate pos ->
                    [ 201, pos ]

                BallUpdate x y dir speed ->
                    Debug.log "Encoding BallUpdate" [ 202, round x, round y, round ((sanifyRadians dir) * 10000), speed ]
    in
        list
            |> List.map Char.fromCode
            |> String.fromList


decode : String -> WSMsg
decode string =
    let
        list =
            string
                |> String.toList
                |> List.map Char.toCode
    in
        case list of
            [ 101 ] ->
                GameStart

            [ 102 ] ->
                GameStop

            [ 103 ] ->
                Miss

            [ 201, pos ] ->
                BatUpdate pos

            [ 202, x, y, dir, speed ] ->
                BallUpdate (toFloat x) (toFloat y) ((toFloat dir) / 10000) speed

            _ ->
                Debug.crash ("Invalid list " ++ toString list)



-- UPDATE


type Msg
    = NewMessage String
    | Tick Time
    | KeyUp Int
    | KeyDown Int


onKeyDown : (Int -> msg) -> Html.Attribute msg
onKeyDown tagger =
    Html.Events.on "keydown" (Json.map tagger Html.Events.keyCode)


onKeyUp : (Int -> msg) -> Html.Attribute msg
onKeyUp tagger =
    Html.Events.on "keyup" (Json.map tagger Html.Events.keyCode)


sanifyRadians : Float -> Float
sanifyRadians radians_ =
    if radians_ < 0 then
        sanifyRadians (radians_ + tau)
    else if radians_ > tau then
        sanifyRadians (radians_ - tau)
    else
        Debug.log "Fixed Radians" radians_


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        send : WSMsg -> Cmd msg
        send wsmsg =
            WebSocket.send model.wsserver (encode wsmsg)
    in
        case msg of
            NewMessage encodedMsg ->
                let
                    msg =
                        decode encodedMsg
                in
                    case msg of
                        GameStart ->
                            ( { model | game = Active (ActiveGame 0 0 0 0 0 0 True) }, Cmd.none )

                        GameStop ->
                            ( { model | game = Pending }, Cmd.none )

                        BatUpdate rightY ->
                            case model.game of
                                Active activeGame ->
                                    ( { model
                                        | game =
                                            Active { activeGame | rightY = rightY }
                                      }
                                    , Cmd.none
                                    )

                                _ ->
                                    ( model, Cmd.none )

                        BallUpdate x y dir speed ->
                            case model.game of
                                Active activeGame ->
                                    ( { model
                                        | game =
                                            Active
                                                { activeGame
                                                    | ballX = x
                                                    , ballY = y
                                                    , ballDir = dir
                                                    , ballSpeed = speed
                                                    , waitForBallUpdate = False
                                                }
                                      }
                                    , Cmd.none
                                    )

                                _ ->
                                    ( model, Cmd.none )

                        Miss ->
                            ( { model | game = GameOver True }, Cmd.none )

            Tick _ ->
                case model.game of
                    Active activeGame ->
                        if activeGame.waitForBallUpdate then
                            ( model, Cmd.none )
                        else if activeGame.ballX < (10 + 20) then
                            -- Check if the ball hit the bat.
                            if activeGame.ballY >= toFloat (activeGame.leftY - 50) && activeGame.ballY <= toFloat (activeGame.leftY + 50) then
                                -- The ball hit the bat.
                                let
                                    nextGameState =
                                        updateBallPos { activeGame | ballDir = pi - activeGame.ballDir, ballSpeed = activeGame.ballSpeed + 5 }
                                in
                                    ( { model | game = Active ({ activeGame | waitForBallUpdate = True }) }
                                    , send (BallUpdate nextGameState.ballX nextGameState.ballY nextGameState.ballDir nextGameState.ballSpeed)
                                    )
                            else
                                -- The ball did not hit the bat
                                ( { model | game = GameOver False }, send Miss )
                        else if activeGame.ballY < 10 || activeGame.ballY > (450 - 10) then
                            ( { model | game = Active (updateBallPos { activeGame | ballDir = tau - activeGame.ballDir }) }
                            , Cmd.none
                            )
                        else
                            ( { model | game = Active (updateBallPos activeGame) }
                            , Cmd.none
                            )

                    _ ->
                        ( model, Cmd.none )

            KeyUp msg ->
                ( model, Cmd.none )

            KeyDown msg ->
                case model.game of
                    Active activeGame ->
                        if msg == 38 then
                            ( { model | game = Active { activeGame | leftY = activeGame.leftY - 30 } }, send (BatUpdate (activeGame.leftY - 30)) )
                        else if msg == 40 then
                            ( { model | game = Active { activeGame | leftY = activeGame.leftY + 30 } }, send (BatUpdate (activeGame.leftY + 30)) )
                        else
                            ( { model | game = Active activeGame }, Cmd.none )

                    _ ->
                        ( model, Cmd.none )


updateBallPos : ActiveGame -> ActiveGame
updateBallPos activeGame =
    { activeGame
        | ballX = activeGame.ballX + cos activeGame.ballDir * toFloat activeGame.ballSpeed
        , ballY = activeGame.ballY + sin activeGame.ballDir * toFloat activeGame.ballSpeed
    }


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ WebSocket.listen model.wsserver NewMessage
        , case model.game of
            Active _ ->
                Time.every (40 * millisecond) Tick

            _ ->
                Sub.none
        ]



-- VIEW


view : Model -> Html Msg
view model =
    div
        [ style
            [ ( "width", "100vw" )
            , ( "height", "100vh" )
            , ( "background-color", "black" )
            , ( "display", "flex" )
            , ( "align-items", "center" )
            , ( "justify-content", "center" )
            ]
        , tabindex 0
        , onKeyDown KeyDown
        , onKeyUp KeyUp
        ]
        [ div
            [ style
                [ ( "width", "800px" )
                , ( "height", "450px" )
                , ( "position", "relative" )
                , ( "background-color", "white" )
                , ( "overflow", "hidden" )
                ]
            ]
            (case model.game of
                Active activeGame ->
                    [ text (toString activeGame)
                    , viewBouncher Left activeGame.leftY
                    , viewBouncher Right activeGame.rightY
                    , viewBall activeGame.ballX activeGame.ballY
                    ]

                Pending ->
                    [ text "Waiting for another client to connect..." ]

                GameOver haveIWon ->
                    case haveIWon of
                        True ->
                            [ text "GAME OVER! - VICTORY" ]

                        False ->
                            [ text "GAME OVER! - YOU LOSE" ]
            )
        ]


type Side
    = Left
    | Right


viewBall : Float -> Float -> Html Msg
viewBall x y =
    div
        [ style
            [ ( "width", "20px" )
            , ( "height", "20px" )
            , ( "border-radius", "50%" )
            , ( "background-color", "black" )
            , ( "top", toString (y - 10) ++ "px" )
            , ( "left", toString (x - 10) ++ "px" )
            , ( "position", "absolute" )
            ]
        ]
        []


viewBouncher : Side -> Int -> Html Msg
viewBouncher side y =
    div
        [ style
            [ ( "width", "20px" )
            , ( "height", "100px" )
            , if side == Left then
                ( "background-color", "blue" )
              else
                ( "background-color", "red" )
            , ( "top", toString (y - 50) ++ "px" )
            , if side == Left then
                ( "left", "0px" )
              else
                ( "right", "0px" )
            , ( "position", "absolute" )
            ]
        ]
        []
