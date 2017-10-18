module Main exposing (..)

import Html exposing (Html, br, button, div, text)
import Html.Attributes exposing (style)
import Html.Events exposing (onClick)
import Mouse exposing (..)
import WebSocket


main =
    Html.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- MODEL


type alias Model =
    { leftY : Int, rightY : Int, balX : Int, balY : Int }


init : ( Model, Cmd Msg )
init =
    ( Model 0 0 30 30, Cmd.none )



-- UPDATE


type Msg
    = MouseMove Int
    | NewMessage String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        MouseMove y ->
            ( { model | leftY = y }, WebSocket.send "ws://localhost:8000" (toString y) )

        NewMessage msg ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Mouse.moves (\{ y } -> MouseMove y)
        , WebSocket.listen "ws://localhost:8000" NewMessage
        ]



-- VIEW


view : Model -> Html Msg
view model =
    div []
        [ text (toString model)
        , viewBouncher Left model.leftY
        , viewBouncher Right model.rightY
        , div
            [ style
                [ ( "width", "20px" )
                , ( "height", "20px" )
                , ( "border-radius", "50%" )
                , ( "background-color", "black" )
                , ( "top", toString model.balX ++ "px" )
                , ( "left", toString model.balY ++ "px" )
                , ( "position", "absolute" )
                ]
            ]
            []
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
