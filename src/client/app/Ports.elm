port module Ports exposing (..)

port onKeyDown : (String -> msg) -> Sub msg

port tick : (Float -> msg) -> Sub msg
