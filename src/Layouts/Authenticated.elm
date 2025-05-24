module Layouts.Authenticated exposing (Model, Msg, Props, layout)

import Accessibility.Aria as Aria
import ApiData
import Auth
import Auth.AccessToken as AccessToken
import Auth.Credentials as Credentials
import Auth.User as User
import Components.Button as Button
import Components.Icon as Icon
import Components.LocaleTime as LocaleTime
import CustomElements
import Effect exposing (Effect)
import Html
import Html.Attributes as Attributes
import Html.Events as Events
import Json.Decode as Decode
import Jwt
import Layout exposing (Layout)
import Result.Extra
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
            accessToken =
                Credentials.accessToken props.user.credentials

            infoFromUser =
                Ok Tuple.pair
                    |> Result.Extra.andMap (AccessToken.expiresAt accessToken)
                    |> Result.Extra.andMap (AccessToken.decode (Decode.field "iat" Decode.int) accessToken)
        in
        [ Html.div [ Attributes.class "grid grid-cols-[auto_1fr] min-h-dvh" ]
            [ Html.aside [ Attributes.class "p-4 bg-gray-100 shadow-lg" ]
                ((case infoFromUser of
                    Ok ( expiresAt, issuedAt ) ->
                        let
                            expMillis =
                                Time.millisToPosix (expiresAt * 1000)

                            iatMillis =
                                Time.millisToPosix (issuedAt * 1000)

                            user =
                                Credentials.user props.user.credentials
                        in
                        [ Html.dl [ Attributes.class "text-sm grid gap-3 p-2" ]
                            (let
                                displayTime posix =
                                    LocaleTime.new posix
                                        |> LocaleTime.toHtml
                                        |> Html.div [ Attributes.class "grid" ]

                                defs =
                                    [ ( "Logged in", Html.text (User.username user ++ " (" ++ User.email user ++ ")") )
                                    , ( "Issued", displayTime iatMillis )
                                    , ( "Expires", displayTime expMillis )
                                    ]
                             in
                             defs
                                |> List.map
                                    (\( label, value ) ->
                                        Html.div [ Attributes.class "grid" ]
                                            [ Html.dd [ Attributes.class "text-sm font-semibold" ]
                                                [ Html.text label ]
                                            , Html.dt [ Attributes.class "max-w-prose line-clamp-1" ] [ value ]
                                            ]
                                    )
                            )
                        , Button.new
                            |> Button.withOnClick (toContentMsg UserClickedLogOut)
                            |> Button.withSecondarySmallClass
                            |> Button.withLoading (ApiData.isLoading shared.logout)
                            |> Button.toHtml [ Html.text "Log out" ]
                        , Html.div [ Attributes.class "flex gap-4 items-baseline" ]
                            [ let
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
            , Html.div []
                [ Html.header [ Attributes.class "p-4" ]
                    [ Html.h1
                        [ Attributes.class "text-2xl font-bold" ]
                        [ Html.text content.title ]
                    ]
                , Html.main_ [ Attributes.class "p-4" ] content.body
                ]
            ]
        ]
    }
