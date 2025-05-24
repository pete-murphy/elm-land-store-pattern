module Layouts.Authenticated exposing (Model, Msg, Props, layout)

import Accessibility.Aria as Aria
import ApiData
import Auth
import Auth.AccessToken as AccessToken
import Auth.Credentials as Credentials
import Auth.User as User
import Components.Icon as Icon
import CustomElements
import Effect exposing (Effect)
import Html
import Html.Attributes as Attributes
import Html.Events as Events
import Json.Decode as Decode
import Jwt
import Layout exposing (Layout)
import Route exposing (Route)
import Route.Path
import Shared
import Shared.Model
import Svg.Attributes
import Time
import View exposing (View)


type alias Props =
    { user : Auth.User }


layout : Props -> Shared.Model -> Route () -> Layout () Model Msg contentMsg
layout props shared route =
    Layout.new
        { init = init
        , update = update props shared
        , view =
            case shared of
                Ok okShared ->
                    view props okShared route

                Err _ ->
                    \_ -> View.none
        , subscriptions = subscriptions
        }



-- MODEL


type alias Model =
    {}


init : () -> ( Model, Effect Msg )
init _ =
    ( {}
    , Effect.none
    )



-- UPDATE


type Msg
    = UserClickedRenew
    | UserClickedLogOut
    | SharedMsg Shared.Msg


update : Props -> Shared.Model -> Msg -> Model -> ( Model, Effect Msg )
update _ _ msg model =
    case msg of
        UserClickedRenew ->
            ( model
            , Effect.renewToken
            )

        UserClickedLogOut ->
            ( model
            , Effect.logOut
            )

        SharedMsg sharedMsg ->
            ( model
            , Effect.sendSharedMsg sharedMsg
            )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view :
    Props
    -> Shared.Model.OkModel
    -> Route ()
    -> { toContentMsg : Msg -> contentMsg, content : View contentMsg, model : Model }
    -> View contentMsg
view props shared currentRoute { toContentMsg, content } =
    { title = content.title
    , body =
        let
            userCredentials =
                props.user.credentials

            accessToken =
                Credentials.accessToken userCredentials

            infoFromUser =
                Result.map2
                    (\expiresAt issuedAt ->
                        { expiresAt = expiresAt
                        , issuedAt = issuedAt
                        }
                    )
                    (AccessToken.expiresAt accessToken)
                    (AccessToken.decode (Decode.field "iat" Decode.int) accessToken)
        in
        [ Html.header [ Attributes.class "p-4 bg-gray-100 shadow-lg" ]
            (Html.h1
                [ Attributes.class "text-2xl font-bold" ]
                [ Html.text content.title ]
                :: (case infoFromUser of
                        Ok info ->
                            let
                                expMillis =
                                    Time.millisToPosix (info.expiresAt * 1000)

                                iatMillis =
                                    Time.millisToPosix (info.issuedAt * 1000)
                            in
                            [ Html.div [ Attributes.class "flex gap-4 items-baseline" ]
                                [ Html.p []
                                    [ Html.text "Logged in as "
                                    , Html.text (User.username (Credentials.user userCredentials))
                                    , Html.text " ("
                                    , Html.text (User.email (Credentials.user userCredentials))
                                    , Html.text ")"
                                    ]
                                , let
                                    loading =
                                        ApiData.isLoading shared.logout
                                  in
                                  Html.button
                                    [ Attributes.class "grid relative place-items-center py-1 px-2 text-sm font-semibold rounded-lg aria-disabled:opacity-75 aria-disabled:cursor-not-allowed *:[grid-area:1/-1] hover:bg-gray-800/5 active:bg-gray-800/10"
                                    , Aria.disabled loading
                                    , Events.onClick (toContentMsg UserClickedLogOut)
                                    ]
                                    [ Html.span [ Attributes.classList [ ( "invisible", loading ) ] ]
                                        [ Html.text "Log out" ]
                                    , if loading then
                                        Icon.view [ Svg.Attributes.class "size-4" ]
                                            Icon.spinningThreeQuarterCircle

                                      else
                                        Html.text ""
                                    ]
                                ]
                            , Html.div [ Attributes.class "flex gap-4 items-baseline" ]
                                [ Html.p []
                                    [ Html.text "Token expires "

                                    -- , CustomElements.localeAndRelativeTime
                                    --     { posix = expMillis
                                    --     , timeStyle = Just "long"
                                    --     , dateStyle = Nothing
                                    --     }
                                    --     []
                                    -- , Html.text ", issued "
                                    -- , CustomElements.localeAndRelativeTime
                                    --     { posix = iatMillis
                                    --     , timeStyle = Just "long"
                                    --     , dateStyle = Nothing
                                    --     }
                                    --     []
                                    ]
                                , let
                                    loading =
                                        ApiData.isLoading shared.credentials
                                  in
                                  Html.button
                                    [ Attributes.class "grid relative place-items-center py-1 px-2 text-sm font-semibold rounded-lg rid aria-disabled:opacity-75 aria-disabled:cursor-not-allowed *:[grid-area:1/-1] hover:bg-gray-800/5 active:bg-gray-800/10"
                                    , Aria.disabled loading
                                    , Events.onClick (toContentMsg UserClickedRenew)
                                    ]
                                    [ Html.span [ Attributes.classList [ ( "invisible", loading ) ] ]
                                        [ Html.text "Renew" ]
                                    , if loading then
                                        Icon.view [ Svg.Attributes.class "size-4" ]
                                            Icon.spinningThreeQuarterCircle

                                      else
                                        Html.text ""
                                    ]
                                ]
                            ]

                        Err err ->
                            [ Html.div []
                                [ Html.text "Error decoding JWT: "
                                , Html.text (Jwt.errorToString err)
                                ]
                            ]
                   )
                ++ (let
                        navLink path =
                            Html.a
                                (Attributes.class "font-semibold"
                                    :: (if path == currentRoute.path then
                                            [ Aria.currentPage ]

                                        else
                                            [ Route.Path.href path ]
                                       )
                                )
                    in
                    [ Html.nav []
                        [ Html.ul [ Attributes.class "flex gap-4" ]
                            ([ ( Route.Path.Home_, "Home" )
                             ]
                                |> List.map
                                    (\( path, text ) ->
                                        Html.li []
                                            [ navLink path [ Html.text text ]
                                            ]
                                    )
                            )
                        ]
                    ]
                   )
            )
        , Html.main_ [ Attributes.class "p-4" ] content.body
        ]
    }
