module Shared.Model exposing (Model, OkModel, store)

{-| -}

import ApiData exposing (ApiData)
import Auth.Credentials exposing (Credentials)
import Dict
import Http.Extra
import Json.Decode as Decode
import Json.Encode as Encode
import Paginated exposing (Paginated)
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
    , store :
        { paginated : Store (Paginated Encode.Value)
        , unpaginated : Store Encode.Value
        }
    }


type alias Data a =
    ApiData Http.Extra.DetailedError a



-- ACCESSOR


store :
    Model
    ->
        { paginated : Store (Paginated Encode.Value)
        , unpaginated : Store Encode.Value
        }
store model =
    case model of
        Ok okModel ->
            okModel.store

        Err _ ->
            { paginated = Dict.empty
            , unpaginated = Dict.empty
            }
