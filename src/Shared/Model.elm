module Shared.Model exposing (Model, OkModel, store)

{-| -}

import Auth.Credentials exposing (Credentials)
import Dict
import Http.DetailedError exposing (DetailedError)
import Json.Decode as Decode
import Loadable exposing (Loadable)
import Store exposing (Store)


{-| Normally, this value would live in "Shared.elm"
but that would lead to a circular dependency import cycle.

For that reason, both `Shared.Model` and `Shared.Msg` are in their
own file, so they can be imported by `Effect.elm`

-}
type alias Model =
    Result Decode.Error OkModel


type alias OkModel =
    { credentials : Data Credentials
    , logout : Data ()
    , store : Store
    }


type alias Data a =
    Loadable DetailedError a



-- ACCESSOR


store :
    Model
    -> Store
store model =
    case model of
        Ok okModel ->
            okModel.store

        Err _ ->
            Dict.empty
