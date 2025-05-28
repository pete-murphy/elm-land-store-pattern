module Shared exposing
    ( Flags, decoder
    , Model, Msg
    , init, update, subscriptions
    )

{-|

@docs Flags, decoder
@docs Model, Msg
@docs init, update, subscriptions

-}

import Api.Auth
import Auth.Credentials as Credentials exposing (Credentials)
import Auth.Route
import Dict
import Effect exposing (Effect)
import Json.Decode
import Json.Decode.Pipeline
import Loadable
import Route exposing (Route)
import Shared.Model
import Shared.Msg
import Store



-- FLAGS


type alias Flags =
    { credentials : Maybe Credentials }


decoder : Json.Decode.Decoder Flags
decoder =
    Json.Decode.succeed Flags
        |> Json.Decode.Pipeline.required "credentials"
            (Credentials.loginResponseDecoder
                |> Json.Decode.map Credentials.create
                |> Json.Decode.nullable
            )



-- INIT


type alias Model =
    Shared.Model.Model


init : Result Json.Decode.Error Flags -> Route () -> ( Model, Effect Msg )
init flagsResult _ =
    case flagsResult of
        Ok flags ->
            ( Ok
                { credentials = Loadable.fromMaybe flags.credentials
                , logout = Loadable.notAsked
                , store = Dict.empty
                , paginatedStrategy = Store.NextPage
                , strategy = Store.CacheFirst
                }
            , Effect.none
            )

        Err err ->
            ( Err err
            , Effect.none
            )



-- UPDATE


type alias Msg =
    Shared.Msg.Msg


update : Route () -> Msg -> Model -> ( Model, Effect Msg )
update route msg model =
    case model of
        Err _ ->
            ( model
            , Effect.none
            )

        Ok okModel ->
            updateOk route msg okModel
                |> Tuple.mapFirst Ok


updateOk : Route () -> Msg -> Shared.Model.OkModel -> ( Shared.Model.OkModel, Effect Msg )
updateOk route msg model =
    case msg of
        Shared.Msg.NoOp ->
            ( model
            , Effect.none
            )

        Shared.Msg.UserSubmittedLogin loginRequest ->
            ( { model | credentials = Loadable.loading }
            , Effect.login loginRequest
            )

        Shared.Msg.BackendRespondedToLogin result ->
            case result of
                Ok loginResponse ->
                    ( { model
                        | credentials = Loadable.succeed (Credentials.create loginResponse)
                      }
                    , Effect.pushRoutePath (Auth.Route.fromLogin route)
                    )

                Err err ->
                    ( { model | credentials = Loadable.fail err }
                    , Effect.none
                    )

        Shared.Msg.BackendRespondedToLogout result ->
            case result of
                Ok () ->
                    ( { model
                        | credentials = Loadable.notAsked
                        , logout = Loadable.succeed ()
                      }
                    , Effect.pushRoutePath (Auth.Route.fromLogin route)
                    )

                Err err ->
                    ( { model | logout = Loadable.fail err }
                    , Effect.none
                    )

        Shared.Msg.BackendRespondedToRenewToken result ->
            case result of
                Ok ok ->
                    ( { model
                        | credentials =
                            Loadable.map (Credentials.updateTokens ok.accessToken ok.refreshToken) model.credentials
                                |> Loadable.toNotLoading
                      }
                    , Effect.none
                    )

                Err err ->
                    ( { model | credentials = Loadable.fail err }
                    , Effect.none
                    )

        Shared.Msg.UserClickedLogOut ->
            ( { model | logout = Loadable.toLoading model.logout }
            , case Loadable.value model.credentials of
                Loadable.Success credentials ->
                    Effect.requestNoContent (Api.Auth.logout credentials)
                        Shared.Msg.BackendRespondedToLogout

                _ ->
                    Effect.none
            )

        Shared.Msg.UserClickedRenewToken ->
            ( { model | credentials = Loadable.toLoading model.credentials }
            , case Loadable.value model.credentials of
                Loadable.Success credentials ->
                    Effect.request (Api.Auth.refresh credentials)
                        Shared.Msg.BackendRespondedToRenewToken

                _ ->
                    Effect.none
            )

        Shared.Msg.StoreRequest strategy storeMsg ->
            let
                ( newStore, maybeRequest ) =
                    Store.handleRequest strategy storeMsg model.store
            in
            ( { model | store = newStore }
            , case maybeRequest of
                Just request ->
                    Effect.request request
                        (Shared.Msg.StoreResponse storeMsg)

                Nothing ->
                    Effect.none
            )

        Shared.Msg.StoreRequestPaginated strategy storeMsg ->
            let
                ( newStore, maybeRequest ) =
                    Store.handleRequestPaginated strategy storeMsg model.store
            in
            ( { model | store = newStore }
            , case maybeRequest of
                Just request ->
                    Effect.request request
                        (Shared.Msg.StoreResponsePaginated storeMsg)

                Nothing ->
                    Effect.none
            )

        Shared.Msg.StoreResponse storeMsg result ->
            let
                newStore =
                    Store.handleResponse storeMsg result model.store
            in
            ( { model | store = newStore }
            , Effect.none
            )

        Shared.Msg.StoreResponsePaginated storeMsg result ->
            let
                newStore =
                    Store.handleResponsePaginated storeMsg result model.store
            in
            ( { model | store = newStore }
            , Effect.none
            )

        Shared.Msg.UserSetPaginatedStrategy paginatedStrategy ->
            ( { model | paginatedStrategy = paginatedStrategy }
            , Effect.none
            )

        Shared.Msg.UserSetStrategy strategy ->
            ( { model | strategy = strategy }
            , Effect.none
            )

        Shared.Msg.UserClickedClearStore ->
            ( { model | store = Dict.empty }
            , Effect.none
            )



-- SUBSCRIPTIONS


subscriptions : Route () -> Model -> Sub Msg
subscriptions _ _ =
    Sub.none
