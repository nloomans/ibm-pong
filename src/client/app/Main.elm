module Main exposing (..)

import Char
import Html exposing (Html, br, button, div, text)
import Html.Attributes exposing (style, tabindex)
import Html.Events exposing (onClick)
import Time exposing (Time, millisecond)
import Mouse exposing (..)
import WebSocket
import Json.Decode as Json


tau =
    2 * pi


main =
    Html.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- MODEL


type alias ActiveModel =
    { leftY : Int, rightY : Int, balX : Float, balY : Float, ballDir : Float, ballSpeed : Float }


type Model
    = Active ActiveModel
    | Pending


init : ( Model, Cmd Msg )
init =
    -- ( Active (ActiveModel 0 0 30 30 (0.1 * tau) 5), Cmd.none )
    ( Pending, Cmd.none )


type WSMsg
    = BatUpdate Int
    | GameStart


encode : WSMsg -> String
encode wsMsg =
    let
        list =
            case wsMsg of
                GameStart ->
                    [ 101 ]

                BatUpdate pos ->
                    [ 201, pos ]
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


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NewMessage encodedMsg ->
            let
                msg =
                    decode encodedMsg
            in
                ( Active (ActiveModel 0 0 30 30 (0.1 * tau) 5), Cmd.none )

        Tick _ ->
            case model of
                Active activeModel ->
                    if activeModel.balX > 800 - 2 * 20 || activeModel.balX < 20 then
                        -- 20 for the ball and 20 for the bat
                        ( Active (updateBallPos { activeModel | ballDir = pi - activeModel.ballDir })
                        , Cmd.none
                        )
                    else if activeModel.balY > 450 - 20 || activeModel.balY < 0 then
                        ( Active (updateBallPos { activeModel | ballDir = tau - activeModel.ballDir })
                        , Cmd.none
                        )
                    else
                        ( Active (updateBallPos activeModel)
                        , Cmd.none
                        )

                Pending ->
                    ( model, Cmd.none )

        KeyUp msg ->
            ( model, Cmd.none )

        KeyDown msg ->
            case model of
                Active activeModel ->
                    if msg == 38 then
                        ( Active { activeModel | leftY = activeModel.leftY - 30 }, WebSocket.send "ws://localhost:8000" (encode (BatUpdate activeModel.leftY)) )
                    else if msg == 40 then
                        ( Active { activeModel | leftY = activeModel.leftY + 30 }, WebSocket.send "ws://localhost:8000" (encode (BatUpdate activeModel.leftY)) )
                    else
                        ( Active activeModel, Cmd.none )

                Pending ->
                    ( model, Cmd.none )


updateBallPos : ActiveModel -> ActiveModel
updateBallPos activeModel =
    { activeModel
        | balX = activeModel.balX + cos activeModel.ballDir * activeModel.ballSpeed
        , balY = activeModel.balY + sin activeModel.ballDir * activeModel.ballSpeed
    }


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ WebSocket.listen "ws://localhost:8000" NewMessage
        , case model of
            Active _ ->
                Time.every (40 * millisecond) Tick

            Pending ->
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
            (case model of
                Active activeModel ->
                    [ text (toString activeModel)
                    , viewBouncher Left activeModel.leftY
                    , viewBouncher Right activeModel.rightY
                    , div
                        [ style
                            [ ( "width", "20px" )
                            , ( "height", "20px" )
                            , ( "border-radius", "50%" )
                            , ( "background-color", "black" )
                            , ( "top", toString activeModel.balY ++ "px" )
                            , ( "left", toString activeModel.balX ++ "px" )
                            , ( "position", "absolute" )
                            ]
                        ]
                        []
                    ]

                Pending ->
                    [ text "Waiting for another client to connect..." ]
            )
        ]


type Side
    = Left
    | Right


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
