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
import ApiData
import Auth.Credentials as Credentials exposing (Credentials)
import Auth.Route
import Dict
import Effect exposing (Effect)
import Json.Decode
import Json.Decode.Pipeline
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
                { credentials = ApiData.fromMaybe flags.credentials
                , logout = ApiData.notAsked
                , store =
                    { paginated = Dict.empty
                    , unpaginated = Dict.empty
                    }
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
    let
        modelStore =
            model.store
    in
    case msg of
        Shared.Msg.NoOp ->
            ( model
            , Effect.none
            )

        Shared.Msg.UserSubmittedLogin loginRequest ->
            ( { model | credentials = ApiData.loading }
            , Effect.login loginRequest
            )

        Shared.Msg.BackendRespondedToLogin result ->
            case result of
                Ok loginResponse ->
                    ( { model
                        | credentials = ApiData.succeed (Credentials.create loginResponse)
                      }
                    , Effect.pushRoutePath (Auth.Route.fromLogin route)
                    )

                Err err ->
                    ( { model | credentials = ApiData.fail err }
                    , Effect.none
                    )

        Shared.Msg.BackendRespondedToLogout result ->
            case result of
                Ok () ->
                    ( { model
                        | credentials = ApiData.notAsked
                        , logout = ApiData.succeed ()
                      }
                    , Effect.pushRoutePath (Auth.Route.fromLogin route)
                    )

                Err err ->
                    ( { model | logout = ApiData.fail err }
                    , Effect.none
                    )

        Shared.Msg.BackendRespondedToRenewToken result ->
            case result of
                Ok token ->
                    ( { model
                        | credentials =
                            ApiData.map (Credentials.updateWithRefreshResponse token) model.credentials
                                |> ApiData.toNotLoading
                      }
                    , Effect.none
                    )

                Err err ->
                    ( { model | credentials = ApiData.fail err }
                    , Effect.none
                    )

        Shared.Msg.UserClickedLogOut ->
            ( { model | logout = ApiData.toLoading model.logout }
            , case ApiData.value model.credentials of
                ApiData.Success credentials ->
                    Effect.request (Api.Auth.logout credentials)
                        Shared.Msg.BackendRespondedToLogout

                _ ->
                    Effect.none
            )

        Shared.Msg.UserClickedRenewToken ->
            ( { model | credentials = ApiData.toLoading model.credentials }
            , case ApiData.value model.credentials of
                ApiData.Success credentials ->
                    Effect.request (Api.Auth.refresh credentials)
                        Shared.Msg.BackendRespondedToRenewToken

                _ ->
                    Effect.none
            )

        Shared.Msg.StoreRequest strategy storeMsg ->
            let
                ( newStore, maybeRequest ) =
                    Store.handleRequest strategy storeMsg modelStore.unpaginated
            in
            ( { model | store = { modelStore | unpaginated = newStore } }
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
                    Store.handleRequestPaginated strategy storeMsg modelStore.paginated
            in
            ( { model | store = { modelStore | paginated = newStore } }
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
                    Store.handleResponse storeMsg result modelStore.unpaginated
            in
            ( { model | store = { modelStore | unpaginated = newStore } }
            , Effect.none
            )

        Shared.Msg.StoreResponsePaginated storeMsg result ->
            let
                newStore =
                    Store.handleResponsePaginated storeMsg result modelStore.paginated
            in
            ( { model | store = { modelStore | paginated = newStore } }
            , Effect.none
            )



-- SUBSCRIPTIONS


subscriptions : Route () -> Model -> Sub Msg
subscriptions _ _ =
    Sub.none
