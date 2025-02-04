module Partnerships.Update exposing (init, update)

import Partnerships.Types exposing (Model, Msg)
import Return exposing (Return, singleton)


init : Model
init =
    { topic = ""
    , title = "Partnerships - Flint"
    , isPhoneMenuVisible = False
    }


update : Msg -> Model -> Return Msg Model
update _ model =
    singleton { model | isPhoneMenuVisible = not model.isPhoneMenuVisible }
