module Layouts.Authenticated exposing (Model, Msg, Props, layout)

import Accessibility.Aria as Aria
import Auth
import Auth.AccessToken as AccessToken
import Auth.Credentials as Credentials exposing (Credentials)
import Auth.User as User
import Components.Button as Button
import Components.Icon as Icon
import Components.LocaleTime as LocaleTime
import Effect exposing (Effect)
import Html
import Html.Attributes as Attributes
import Json.Decode as Decode
import Jwt
import Layout exposing (Layout)
import Loadable
import Result.Extra
import Route exposing (Route)
import Route.Path
import Shared
import Shared.Model
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
        [ Html.div [ Attributes.class "grid mx-auto max-w-3xl grid-cols-[auto_1fr]" ]
            [ Html.aside [ Attributes.class "sticky grid top-0 left-0 p-4 h-dvh" ]
                ([ viewNav currentRoute
                 , Html.div [ Attributes.class "self-end" ]
                    [ viewUserInfo props.user.credentials
                    , Html.div [ Attributes.class "flex gap-2" ]
                        [ Button.new
                            |> Button.withOnClick UserClickedRenew
                            |> Button.withSizeSmall
                            |> Button.withVariantSecondary
                            |> Button.withTrailingIcon Icon.arrowPath
                            |> Button.withLoading (Loadable.isLoading shared.credentials)
                            |> Button.withText "Renew"
                            |> Button.toHtml
                        , Button.new
                            |> Button.withOnClick UserClickedLogOut
                            |> Button.withSizeSmall
                            |> Button.withVariantSecondary
                            |> Button.withTrailingIcon Icon.arrowRightStartOnRectanglePath
                            |> Button.withLoading (Loadable.isLoading shared.logout)
                            |> Button.withText "Log out"
                            |> Button.toHtml
                        ]
                    ]
                 ]
                    |> List.map (Html.map toContentMsg)
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


viewUserInfo : Credentials -> Html.Html Msg
viewUserInfo credentials =
    let
        accessToken =
            Credentials.accessToken credentials

        infoFromUser =
            Ok Tuple.pair
                |> Result.Extra.andMap (AccessToken.expiresAt accessToken)
                |> Result.Extra.andMap (AccessToken.decode (Decode.field "iat" Decode.int) accessToken)
    in
    case infoFromUser of
        Ok ( expiresAt, issuedAt ) ->
            Html.dl [ Attributes.class "grid gap-3 p-2 text-sm" ]
                (let
                    user =
                        Credentials.user credentials

                    displayTime posix =
                        LocaleTime.new posix
                            |> LocaleTime.withRelativeAttrs [ Attributes.class "text-xs" ]
                            |> LocaleTime.toHtml
                            |> Html.div [ Attributes.class "grid" ]

                    items =
                        [ ( "Logged in", Html.text (User.username user ++ " (" ++ User.email user ++ ")") )
                        , ( "Issued", displayTime (Time.millisToPosix (issuedAt * 1000)) )
                        , ( "Expires", displayTime (Time.millisToPosix (expiresAt * 1000)) )
                        ]
                 in
                 items
                    |> List.map
                        (\( label, value ) ->
                            Html.div [ Attributes.class "grid" ]
                                [ Html.dd [ Attributes.class "text-sm font-semibold" ]
                                    [ Html.text label ]
                                , Html.dt [ Attributes.class "max-w-prose line-clamp-1" ] [ value ]
                                ]
                        )
                )

        Err err ->
            Html.div []
                [ Html.text "Error decoding JWT: "
                , Html.text (Jwt.errorToString err)
                ]


viewNav : Route () -> Html.Html msg
viewNav currentRoute =
    let
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
    Html.nav [ Attributes.class "p-2" ]
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
