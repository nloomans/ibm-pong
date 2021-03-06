module Main exposing (..)

import Char
import Html exposing (Html, div, text)
import Html.Attributes exposing (style)
import Time exposing (Time)
import WebSocket
import Ports exposing (onKeyDown, tick)


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
    -- We are getting the web socket server url from the javascript side, see
    -- index.js
    ( Model Pending flags.wsserver, Cmd.none )


type WSMsg
    = BatUpdate Int
    | BallUpdate Float Float Float Int
    | GameStart
    | GameStop
    | Miss



-- Turns a WSMsg into an utf8 encoded string that can be send to the server.
-- Usuage:
--   encode (BatUpdate 30)
-- Returns:
--   A string that should be send to the server.


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
                    [ 202, round x, round y, round ((sanifyRadians dir) * 10000), speed ]
    in
        list
            |> List.map Char.fromCode
            |> String.fromList



-- Decodes a utf8 encoded string into a WSMsg.
-- Usuage:
--   decode "foo" -- Foo is a utf8 encoded string send from the server
--   (or created using `encode`)
-- Returns:
--   A WSMsg, e.g. BatUpdate 30


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
                Debug.crash ("Invalid list from server: " ++ toString list)



-- UPDATE


type Msg
    = NewMessage String
    | Tick Time
    | KeyDown String



-- Turns a crazy radian (e.g. -5pi) into something sane (e.g. 1pi)


sanifyRadians : Float -> Float
sanifyRadians radians_ =
    if radians_ < 0 then
        sanifyRadians (radians_ + tau)
    else if radians_ > tau then
        sanifyRadians (radians_ - tau)
    else
        radians_


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        send : WSMsg -> Cmd Msg
        send wsmsg =
            WebSocket.send model.wsserver (encode wsmsg)
    in
        case msg of
            -- We recieved a msg from the server.
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

                        -- The bat pos of the other player changed.
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

                        -- The position of the ball changes, this is send when
                        -- the other player hit the ball with his bat.
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

                        -- The other player missed the bat, we have won.
                        Miss ->
                            ( { model | game = GameOver True }, Cmd.none )

            -- This function is before a frame is drawn.
            Tick timeDiff ->
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
                                        updateBallPos timeDiff { activeGame | ballDir = pi - activeGame.ballDir, ballSpeed = activeGame.ballSpeed + 2 }
                                in
                                    ( { model | game = Active ({ activeGame | waitForBallUpdate = True }) }
                                    , send (BallUpdate nextGameState.ballX nextGameState.ballY nextGameState.ballDir nextGameState.ballSpeed)
                                    )
                            else
                                -- The ball did not hit the bat
                                ( { model | game = GameOver False }, send Miss )
                            -- Just some wall bounching.
                        else if activeGame.ballY < 10 || activeGame.ballY > (450 - 10) then
                            ( { model | game = Active (updateBallPos timeDiff { activeGame | ballDir = tau - activeGame.ballDir }) }
                            , Cmd.none
                            )
                            -- Nothing special happend, just update the ball pos.
                        else
                            ( { model | game = Active (updateBallPos timeDiff activeGame) }
                            , Cmd.none
                            )

                    _ ->
                        ( model, Cmd.none )

            KeyDown msg ->
                case model.game of
                    Active activeGame ->
                        if msg == "ArrowUp" then
                            -- Move the bat up, and tell the server that our bat has been moved.
                            ( { model | game = Active { activeGame | leftY = activeGame.leftY - 60 } }, send (BatUpdate (activeGame.leftY - 60)) )
                            -- Move the bat down, and tell the server that our bat has been moved.
                        else if msg == "ArrowDown" then
                            ( { model | game = Active { activeGame | leftY = activeGame.leftY + 60 } }, send (BatUpdate (activeGame.leftY + 60)) )
                        else
                            ( model, Cmd.none )

                    _ ->
                        ( model, Cmd.none )



-- Move the ball to his position in the next point in time.


updateBallPos : Time -> ActiveGame -> ActiveGame
updateBallPos timeDiff activeGame =
    { activeGame
        | ballX = activeGame.ballX + cos activeGame.ballDir * toFloat activeGame.ballSpeed * (timeDiff / 16)
        , ballY = activeGame.ballY + sin activeGame.ballDir * toFloat activeGame.ballSpeed * (timeDiff / 16)
    }


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ WebSocket.listen model.wsserver NewMessage
        , onKeyDown KeyDown

        -- Only listen for tick updates when the game is active. This has no
        -- impact apart from making the log cleaner, as this check is made again
        -- in the update function
        , case model.game of
            Active _ ->
                tick Tick

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
            , ( "background-color", "#e2e1e0" )
            , ( "display", "flex" )
            , ( "align-items", "center" )
            , ( "justify-content", "center" )
            ]
        ]
        [ div
            [ style
                [ ( "width", "800px" )
                , ( "height", "450px" )
                , ( "background-color", "white" )
                , ( "overflow", "hidden" )
                , ( "box-shadow", "0 1px 3px rgba(0,0,0,0.12), 0 1px 2px rgba(0,0,0,0.24)" )
                , ( "padding", "32px" )
                ]
            ]
            [ div [ style [ ( "position", "relative" ), ( "overflow", "hidden" ), ( "width", "inherit" ), ( "height", "inherit" ) ] ]
                (case model.game of
                    Active activeGame ->
                        [ viewBouncher Left activeGame.leftY
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
            , ( "background-color", "green" )
            , ( "top", toString (y - 50) ++ "px" )
            , if side == Left then
                ( "left", "0px" )
              else
                ( "right", "0px" )
            , ( "position", "absolute" )
            ]
        ]
        []
