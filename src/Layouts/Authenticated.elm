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
import Html.Events
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
    = UserClickedClearStore
    | UserClickedLogOut
    | UserClickedSetStrategy Store.Strategy
    | UserClickedSetPaginatedStrategy Store.PaginatedStrategy


update : Props -> Shared.Model -> Msg -> Model -> ( Model, Effect Msg )
update _ _ msg model =
    case msg of
        UserClickedClearStore ->
            ( model
            , Effect.clearStore
            )

        UserClickedLogOut ->
            ( model
            , Effect.logOut
            )

        UserClickedSetStrategy strategy ->
            ( model
            , Effect.setStrategy strategy
            )

        UserClickedSetPaginatedStrategy strategy ->
            ( model
            , Effect.setPaginatedStrategy strategy
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
            [ Html.aside [ Attributes.class "grid overflow-y-hidden sticky top-0 left-0 p-8 h-dvh grid-rows-[auto_1fr_auto_auto]" ]
                [ viewNav currentRoute
                , Html.div [ Attributes.class "grid overflow-y-scroll gap-8 grid-rows-[1fr_auto]" ]
                    [ viewStore shared.store ]
                , viewStrategyControls shared toContentMsg
                , Html.div [ Attributes.class "flex flex-wrap gap-2" ]
                    [ Button.new
                        |> Button.withVariantSecondary
                        |> Button.withText "Clear store"
                        |> Button.withTrailingIcon Path.trash
                        |> Button.withOnClick (toContentMsg UserClickedClearStore)
                        |> Button.withSizeSmall
                        |> Button.withLoading (Loadable.isLoading shared.credentials)
                        |> Button.toHtml
                    , Button.new
                        |> Button.withVariantSecondary
                        |> Button.withText "Log out"
                        |> Button.withTrailingIcon Path.arrowRightStartOnRectangle
                        |> Button.withOnClick (toContentMsg UserClickedLogOut)
                        |> Button.withSizeSmall
                        |> Button.withLoading (Loadable.isLoading shared.logout)
                        |> Button.toHtml
                    ]
                ]
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
    Html.dl [ Attributes.class "flex flex-col gap-2 justify-end" ]
        (Dict.toList store
            |> List.map
                (\( k, v ) ->
                    Html.div [ Attributes.class "grid font-mono text-xs" ]
                        [ Html.dt []
                            [ Html.text k
                            ]
                        , Html.dd [ Attributes.class "grid relative grid-flow-col gap-2 items-center" ]
                            [ let
                                orLoading x =
                                    if Loadable.isLoading v then
                                        Icon.view Icon.Micro [ Svg.Attributes.class "animate-spin" ] Path.arrowPath

                                    else
                                        x

                                expandButton id text =
                                    [ Html.button
                                        [ Attributes.attribute "popovertarget" id
                                        , Attributes.class "inline-grid p-0.5 max-w-full rounded-sm overflow-clip text-start text-ellipsis hover:bg-[oklch(from_currentColor_l_c_h_/_0.05)]"
                                        , Attributes.style "anchor-name" ("--anchor_" ++ id)
                                        ]
                                        [ Html.span [ Attributes.class "line-clamp-1" ] [ Html.text text ] ]
                                    , Html.div
                                        [ Attributes.id id
                                        , Attributes.attribute "popover" "auto"
                                        , Attributes.class "absolute p-2 m-0 font-semibold whitespace-pre rounded-lg opacity-0 transition duration-100 -translate-x-4 text-nowrap overflow-x-clip text-ellipsis backdrop-blur-md bg-gray-800/90 text-[oklch(from_currentColor_1_c_h)] transition-discrete open:opacity-100 open:translate-x-0 open:scale-100 open:starting:-translate-x-4 open:starting:scale-98 scale-98 max-h-[50dvh] max-w-[min(60dvw,120ch)] [position-area:right_center] [position-try-fallbacks:flip-start]"
                                        , Attributes.style "position-anchor" ("--anchor_" ++ id)
                                        ]
                                        [ Html.text text ]
                                    ]
                              in
                              case Loadable.value v of
                                Loadable.Empty ->
                                    Html.span [ Attributes.class "grid gap-1 items-center text-gray-600 grid-cols-[auto_1fr]" ]
                                        [ Icon.view Icon.Micro [ Svg.Attributes.class "" ] Path.ellipsisHorizontal
                                            |> orLoading
                                        , Html.span [ Attributes.class "p-0.5 line-clamp-1" ] [ Html.text "Empty" ]
                                        ]

                                Loadable.Failure failure ->
                                    Html.span [ Attributes.class "grid grid-flow-col gap-1 items-center text-red-600" ]
                                        ((Icon.view Icon.Micro [ Svg.Attributes.class "" ] Path.xMark |> orLoading)
                                            -- , Html.span [ Attributes.class "line-clamp-1" ] [ Html.text (DetailedError.toString failure) ]
                                            :: expandButton ("failure_" ++ k) (DetailedError.toString failure)
                                        )

                                Loadable.Success success ->
                                    Html.span [ Attributes.class "grid grid-flow-col gap-1 items-center text-green-600" ]
                                        ((Icon.view Icon.Micro [ Svg.Attributes.class "" ] Path.check |> orLoading)
                                            --  Html.span [ Attributes.class "line-clamp-1" ] [ Html.text (Json.Encode.encode 0 success) ]
                                            :: expandButton ("success_" ++ k) (Json.Encode.encode 2 success)
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


viewStrategyControls : Shared.Model.OkModel -> (Msg -> contentMsg) -> Html.Html contentMsg
viewStrategyControls shared toContentMsg =
    Html.div [ Attributes.class "flex flex-col gap-1 text-xs h-fit" ]
        [ Html.div [ Attributes.class "grid gap-1" ]
            [ Html.h3 [ Attributes.class "font-semibold text-gray-700" ] [ Html.text "Strategy" ]
            , Html.div [ Attributes.class "grid" ]
                [ radioButton
                    "strategy-cache-first"
                    "CacheFirst"
                    (shared.strategy == Store.CacheFirst)
                    (toContentMsg (UserClickedSetStrategy Store.CacheFirst))
                , radioButton
                    "strategy-network-only"
                    "NetworkOnly"
                    (shared.strategy == Store.NetworkOnly)
                    (toContentMsg (UserClickedSetStrategy Store.NetworkOnly))
                , radioButton
                    "strategy-stale-while-revalidate"
                    "StaleWhileRevalidate"
                    (shared.strategy == Store.StaleWhileRevalidate)
                    (toContentMsg (UserClickedSetStrategy Store.StaleWhileRevalidate))
                ]
            ]
        , Html.div [ Attributes.class "grid gap-1" ]
            [ Html.h3 [ Attributes.class "font-semibold text-gray-700" ] [ Html.text "Paginated Strategy" ]
            , Html.div [ Attributes.class "grid" ]
                [ radioButton
                    "paginated-strategy-next-page"
                    "NextPage"
                    (shared.paginatedStrategy == Store.NextPage)
                    (toContentMsg (UserClickedSetPaginatedStrategy Store.NextPage))
                , radioButton
                    "paginated-strategy-reset"
                    "Reset"
                    (shared.paginatedStrategy == Store.Reset)
                    (toContentMsg (UserClickedSetPaginatedStrategy Store.Reset))
                ]
            ]
        ]


radioButton : String -> String -> Bool -> contentMsg -> Html.Html contentMsg
radioButton name label isChecked onClickMsg =
    Html.label
        [ Attributes.class "flex gap-2 items-center p-1 rounded cursor-pointer hover:bg-gray-50" ]
        [ Html.input
            [ Attributes.type_ "radio"
            , Attributes.name name
            , Attributes.checked isChecked
            , Html.Events.onClick onClickMsg
            , Attributes.class "text-blue-600"
            ]
            []
        , Html.span [ Attributes.class "text-gray-600" ] [ Html.text label ]
        ]
