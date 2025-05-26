port module Effect exposing
    ( Effect
    , none, batch
    , sendCmd, sendMsg
    , sendSharedMsg
    , pushRoute, replaceRoute
    , pushRoutePath, replaceRoutePath
    , loadExternalUrl, back
    , login, renewToken, logOut
    , sendStoreRequest, sendStoreRequestPaginated
    , request, requestNoContent
    , focusById
    , map, toCmd
    )

{-|

@docs Effect

@docs none, batch
@docs sendCmd, sendMsg
@docs sendSharedMsg

@docs pushRoute, replaceRoute
@docs pushRoutePath, replaceRoutePath
@docs loadExternalUrl, back

@docs login, renewToken, logOut

@docs sendStoreRequest, sendStoreRequestPaginated
@docs request, requestNoContent

@docs focusById

@docs map, toCmd

-}

-- import Store.Request

import Api.Auth exposing (LoginRequest)
import Browser.Navigation
import Dict exposing (Dict)
import Http.DetailedError exposing (DetailedError)
import Http.Extra
import Json.Encode as Encode
import Paginated
import Route
import Route.Path
import Shared.Model
import Shared.Msg
import Store
import Task
import Url exposing (Url)


type Effect msg
    = -- BASICS
      None
    | Batch (List (Effect msg))
    | SendCmd (Cmd msg)
      -- ROUTING
    | PushUrl String
    | ReplaceUrl String
    | LoadExternalUrl String
    | Back
      -- SHARED
    | SendSharedMsg Shared.Msg.Msg
      -- JavaScript
    | SendToJs Encode.Value



-- BASICS


{-| Don't send any effect.
-}
none : Effect msg
none =
    None


{-| Send multiple effects at once.
-}
batch : List (Effect msg) -> Effect msg
batch =
    Batch


{-| Send a normal `Cmd msg` as an effect, something like `Http.get` or `Random.generate`.
-}
sendCmd : Cmd msg -> Effect msg
sendCmd =
    SendCmd


{-| Send a message as an effect. Useful when emitting events from UI components.
-}
sendMsg : msg -> Effect msg
sendMsg msg =
    Task.succeed msg
        |> Task.perform identity
        |> SendCmd


sendSharedMsg : Shared.Msg.Msg -> Effect msg
sendSharedMsg =
    SendSharedMsg



-- DOM


focusById : String -> Effect msg
focusById id =
    SendToJs
        (Encode.object
            [ ( "type", Encode.string "focusById" )
            , ( "id", Encode.string id )
            ]
        )



-- ROUTING


{-| Set the new route, and make the back button go back to the current route.
-}
pushRoute :
    { path : Route.Path.Path
    , query : Dict String String
    , hash : Maybe String
    }
    -> Effect msg
pushRoute route =
    PushUrl (Route.toString route)


{-| Same as `Effect.pushRoute`, but without `query` or `hash` support
-}
pushRoutePath : Route.Path.Path -> Effect msg
pushRoutePath path =
    PushUrl (Route.Path.toString path)


{-| Set the new route, but replace the previous one, so clicking the back
button **won't** go back to the previous route.
-}
replaceRoute :
    { path : Route.Path.Path
    , query : Dict String String
    , hash : Maybe String
    }
    -> Effect msg
replaceRoute route =
    ReplaceUrl (Route.toString route)


{-| Same as `Effect.replaceRoute`, but without `query` or `hash` support
-}
replaceRoutePath : Route.Path.Path -> Effect msg
replaceRoutePath path =
    ReplaceUrl (Route.Path.toString path)


{-| Redirect users to a new URL, somewhere external to your web application.
-}
loadExternalUrl : String -> Effect msg
loadExternalUrl =
    LoadExternalUrl


{-| Navigate back one page
-}
back : Effect msg
back =
    Back



-- JAVASCRIPT


port toJs : Encode.Value -> Cmd msg



-- HTTP


login : LoginRequest -> Effect Shared.Msg.Msg
login loginRequest =
    Http.Extra.request
        (Api.Auth.login loginRequest)
        Shared.Msg.BackendRespondedToLogin
        |> sendCmd


logOut : Effect msg
logOut =
    SendSharedMsg Shared.Msg.UserClickedLogOut


renewToken : Effect msg
renewToken =
    SendSharedMsg Shared.Msg.UserClickedRenewToken


request :
    Http.Extra.Request a
    -> (Result DetailedError a -> msg)
    -> Effect msg
request req toMsg =
    Http.Extra.request req toMsg
        |> sendCmd


requestNoContent :
    Http.Extra.Request ()
    -> (Result DetailedError () -> msg)
    -> Effect msg
requestNoContent req toMsg =
    Http.Extra.requestNoContent req toMsg
        |> sendCmd



-- STORE


sendStoreRequest : Store.Strategy -> Http.Extra.Request a -> Effect msg
sendStoreRequest strategy req =
    Shared.Msg.StoreRequest strategy
        { path = req.path
        , query = req.query
        , headers = req.headers
        }
        |> SendSharedMsg


sendStoreRequestPaginated : Store.PaginatedStrategy -> Http.Extra.Request (Paginated.Paginated a) -> Effect msg
sendStoreRequestPaginated strategy req =
    Shared.Msg.StoreRequestPaginated strategy
        { path = req.path
        , query = req.query
        , headers = req.headers
        }
        |> SendSharedMsg



-- INTERNALS


{-| Elm Land depends on this function to connect pages and layouts
together into the overall app.
-}
map : (msg1 -> msg2) -> Effect msg1 -> Effect msg2
map fn effect =
    case effect of
        None ->
            None

        Batch list ->
            Batch (List.map (map fn) list)

        SendCmd cmd ->
            SendCmd (Cmd.map fn cmd)

        PushUrl url ->
            PushUrl url

        ReplaceUrl url ->
            ReplaceUrl url

        Back ->
            Back

        LoadExternalUrl url ->
            LoadExternalUrl url

        SendSharedMsg sharedMsg ->
            SendSharedMsg sharedMsg

        SendToJs value ->
            SendToJs value


{-| Elm Land depends on this function to perform your effects.
-}
toCmd :
    { key : Browser.Navigation.Key
    , url : Url
    , shared : Shared.Model.Model
    , fromSharedMsg : Shared.Msg.Msg -> msg
    , batch : List msg -> msg
    , toCmd : msg -> Cmd msg
    }
    -> Effect msg
    -> Cmd msg
toCmd options effect =
    case effect of
        None ->
            Cmd.none

        Batch list ->
            Cmd.batch (List.map (toCmd options) list)

        SendCmd cmd ->
            cmd

        PushUrl url ->
            Browser.Navigation.pushUrl options.key url

        ReplaceUrl url ->
            Browser.Navigation.replaceUrl options.key url

        Back ->
            Browser.Navigation.back options.key 1

        LoadExternalUrl url ->
            Browser.Navigation.load url

        SendSharedMsg sharedMsg ->
            Task.succeed sharedMsg
                |> Task.perform options.fromSharedMsg

        SendToJs value ->
            toJs value
