module Layouts.Authenticated exposing (Model, Msg, Props, layout)

import Accessibility.Aria as Aria
import Auth
import Auth.AccessToken as AccessToken
import Auth.Credentials as Credentials exposing (Credentials)
import Auth.User as User
import Components.Button as Button
import Components.Icon as Icon
import Components.Icon.Path as Path
import Components.LocaleTime as LocaleTime
import Dict
import Effect exposing (Effect)
import Html
import Html.Attributes as Attributes
import Http.DetailedError as DetailedError
import Json.Decode as Decode
import Json.Encode
import Jwt
import Layout exposing (Layout)
import Loadable
import Result.Extra
import Route exposing (Route)
import Route.Path
import Shared
import Shared.Model
import Store exposing (Store)
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
        [ Html.div [ Attributes.class "grid mx-auto max-w-4xl grid-cols-[min(35%,20rem)_1fr]" ]
            [ Html.aside [ Attributes.class "grid sticky top-0 left-0 p-8 h-dvh" ]
                ([ viewNav currentRoute
                 , Html.div [ Attributes.class "grid gap-8 self-end" ]
                    [ viewStore shared.store
                    , Html.div [ Attributes.class "flex flex-wrap gap-2" ]
                        [ Button.new
                            |> Button.withVariantSecondary
                            |> Button.withText "Renew"
                            |> Button.withTrailingIcon Path.arrowPath
                            |> Button.withOnClick UserClickedRenew
                            |> Button.withSizeSmall
                            |> Button.withLoading (Loadable.isLoading shared.credentials)
                            |> Button.toHtml
                        , Button.new
                            |> Button.withVariantSecondary
                            |> Button.withText "Log out"
                            |> Button.withTrailingIcon Path.arrowRightStartOnRectangle
                            |> Button.withOnClick UserClickedLogOut
                            |> Button.withSizeSmall
                            |> Button.withLoading (Loadable.isLoading shared.logout)
                            |> Button.toHtml
                        ]
                    ]
                 ]
                    |> List.map (Html.map toContentMsg)
                )
            , Html.div [ Attributes.class "flex flex-col gap-8 p-8" ]
                [ Html.header []
                    [ Html.h1
                        [ Attributes.class "text-2xl font-bold" ]
                        [ Html.text content.title ]
                    ]
                , Html.main_ [] content.body
                ]
            ]
        ]
    }


viewStore : Store -> Html.Html msg
viewStore store =
    Html.dl [ Attributes.class "grid gap-2" ]
        (Dict.toList store
            |> List.map
                (\( k, v ) ->
                    Html.div [ Attributes.class "grid text-xs font-mono" ]
                        [ Html.dt []
                            [ Html.text k
                            ]
                        , Html.dd [ Attributes.class "grid grid-flow-col gap-2 items-center" ]
                            [ let
                                orLoading x =
                                    if Loadable.isLoading v then
                                        Icon.view Icon.Micro [ Svg.Attributes.class "animate-spin" ] Path.arrowPath

                                    else
                                        x

                                expandButton id text =
                                    [ Html.button
                                        [ Attributes.attribute "popovertarget" id
                                        , Attributes.class "inline-grid overflow-clip max-w-full border text-start text-ellipsis anchor/my-anchor"
                                        ]
                                        [ Html.span [ Attributes.class "line-clamp-1" ] [ Html.text text ] ]
                                    , Html.div
                                        [ Attributes.id id
                                        , Attributes.attribute "popover" "auto"
                                        , Attributes.class "whitespace-pre-wrap max-h-[50dvh] max-w-[80dvw] fixed m-2 anchored-top-center/my-anchor"
                                        ]
                                        [ Html.text text ]
                                    ]
                              in
                              case Loadable.value v of
                                Loadable.Empty ->
                                    Html.span [ Attributes.class "text-gray-600 grid grid-flow-col gap-1 items-center" ]
                                        [ Icon.view Icon.Micro [ Svg.Attributes.class "" ] Path.ellipsisHorizontal
                                            |> orLoading
                                        , Html.span [ Attributes.class "line-clamp-1" ] [ Html.text "Empty" ]
                                        ]

                                Loadable.Failure failure ->
                                    Html.span [ Attributes.class "text-red-600 grid grid-flow-col gap-1 items-center" ]
                                        ((Icon.view Icon.Micro [ Svg.Attributes.class "" ] Path.xMark |> orLoading)
                                            -- , Html.span [ Attributes.class "line-clamp-1" ] [ Html.text (DetailedError.toString failure) ]
                                            :: expandButton "failure" (DetailedError.toString failure)
                                        )

                                Loadable.Success success ->
                                    Html.span [ Attributes.class "text-green-600 grid grid-flow-col gap-1 items-center" ]
                                        ((Icon.view Icon.Micro [ Svg.Attributes.class "" ] Path.check |> orLoading)
                                            --  Html.span [ Attributes.class "line-clamp-1" ] [ Html.text (Json.Encode.encode 0 success) ]
                                            :: expandButton "success" (Json.Encode.encode 2 success)
                                        )
                            ]
                        ]
                )
        )


viewNav : Route () -> Html.Html msg
viewNav currentRoute =
    let
        navLink path =
            Html.a
                (Attributes.class "flex relative gap-2 items-center p-2 font-semibold rounded-md active:transition aria-[current=page]:before:bg-gray-800 before:size-1 before:absolute before:rounded-full before:transition-all before:h-4 before:bg-gray-800/0 before:top-1/2 before:-left-1 before:-translate-x-1/2 before:-translate-y-1/2 hover:not-aria-[current=page]:before:bg-gray-800/25 hover:before:h-[calc(100%-0.5rem)]"
                    :: (if path == currentRoute.path then
                            [ Aria.currentPage ]

                        else
                            [ Route.Path.href path ]
                       )
                )
    in
    Html.nav [ Attributes.class "px-2" ]
        [ Html.ul [ Attributes.class "grid gap-4" ]
            ([ ( Path.home, Route.Path.Home_, "Home" )
             , ( Path.rectangleStack, Route.Path.Posts, "Posts" )
             , ( Path.tag, Route.Path.Tags, "Tags" )
             , ( Path.user, Route.Path.Users, "Users" )
             ]
                |> List.map
                    (\( iconPath, path, text ) ->
                        Html.li [ Attributes.class "group" ]
                            [ navLink path [ Icon.view Icon.Regular [ Svg.Attributes.class "text-gray-400 transition group-hover:text-gray-600 group-has-aria-[current=page]:text-gray-800" ] iconPath, Html.text text ]
                            ]
                    )
            )
        ]
