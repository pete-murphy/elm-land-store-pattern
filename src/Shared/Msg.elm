module Shared.Msg exposing (Msg(..))

{-| -}

import Api.Auth exposing (LoginRequest, RefreshResponse)
import Auth.Credentials exposing (LoginResponse)
import Http.DetailedError exposing (DetailedError)
import Json.Encode as Encode
import Paginated exposing (Paginated)
import Store exposing (PaginatedStrategy, Strategy)
import Store.Request


{-| Normally, this value would live in "Shared.elm"
but that would lead to a circular dependency import cycle.

For that reason, both `Shared.Model` and `Shared.Msg` are in their
own file, so they can be imported by `Effect.elm`

-}
type Msg
    = UserSubmittedLogin LoginRequest
    | UserClickedLogOut
    | UserClickedRenewToken
    | BackendRespondedToLogin (ApiResult LoginResponse)
    | BackendRespondedToRenewToken (ApiResult RefreshResponse)
    | BackendRespondedToLogout (ApiResult ())
      -- STORE
    | StoreRequest Strategy (Store.Request.Msg ())
    | StoreRequestPaginated PaginatedStrategy (Store.Request.Msg Paginated.Config)
    | StoreResponse (Store.Request.Msg ()) (ApiResult Encode.Value)
    | StoreResponsePaginated (Store.Request.Msg Paginated.Config) (ApiResult (Paginated Encode.Value))
      -- NOOP
    | NoOp


type alias ApiResult a =
    Result DetailedError a
