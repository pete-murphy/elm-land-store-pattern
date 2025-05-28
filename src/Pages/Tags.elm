module Pages.Tags exposing (Model, Msg, page)

import Api.Tag exposing (Tag)
import Api.TagId as TagId
import Auth
import Effect exposing (Effect)
import Html exposing (Html)
import Html.Attributes as Attributes
import Http.DetailedError as DetailedError exposing (DetailedError)
import Http.Extra exposing (Request)
import Layouts
import Loadable exposing (Loadable)
import Page exposing (Page)
import Route exposing (Route)
import Route.Path
import Shared
import Shared.Model
import Store
import View exposing (View)


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page user shared _ =
    let
        requests : Requests
        requests =
            { tags = Api.Tag.get user.credentials
            }
    in
    Page.new
        { init = init requests shared
        , update = update
        , view = view requests shared
        , subscriptions = subscriptions
        }
        |> Page.withLayout (toLayout user)


toLayout : Auth.User -> Model -> Layouts.Layout Msg
toLayout user _ =
    Layouts.Authenticated { user = user }



-- INIT


type alias Data a =
    Loadable DetailedError a


type alias Requests =
    { tags : Request (List Tag)
    }


type alias Model =
    {}


init : Requests -> Shared.Model -> () -> ( Model, Effect Msg )
init requests shared _ =
    ( {}
    , Effect.sendStoreRequest (Shared.Model.strategy shared) requests.tags
    )



-- UPDATE


type Msg
    = NoOp


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        NoOp ->
            ( {}
            , Effect.none
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Requests -> Shared.Model -> Model -> View Msg
view requests shared model =
    { title = "Tags"
    , body =
        [ Html.div [ Attributes.class "flex flex-col gap-6" ]
            [ Html.p [ Attributes.class "text-gray-600" ]
                [ Html.text "Discover posts by topic. Click on any tag to see related posts." ]
            , viewTagsSection (Store.get requests.tags (Shared.Model.store shared))
            ]
        ]
    }


viewTagsSection : Data (List Tag) -> Html Msg
viewTagsSection tagsData =
    case Loadable.value tagsData of
        Loadable.Empty ->
            viewSkeletonContent

        Loadable.Failure error ->
            Html.div [ Attributes.class "p-4 text-red-700 bg-red-50 rounded-lg border border-red-200" ]
                [ Html.text ("Error loading tags: " ++ DetailedError.toString error) ]

        Loadable.Success tags ->
            if List.isEmpty tags then
                Html.div [ Attributes.class "py-12 text-center" ]
                    [ Html.div [ Attributes.class "mb-4 text-gray-400" ]
                        [ Html.text "🏷️" ]
                    , Html.p [ Attributes.class "text-gray-600" ]
                        [ Html.text "No tags available yet." ]
                    ]

            else
                Html.div [ Attributes.class "grid gap-4" ]
                    [ Html.ul [ Attributes.class "grid gap-4 grid-cols-[repeat(auto-fill,minmax(12rem,1fr))]" ]
                        (List.map viewTag tags)
                    ]


viewTag : Tag -> Html Msg
viewTag tag =
    let
        tagId =
            TagId.toString tag.id
    in
    Html.li
        [ Attributes.class "block relative p-6 rounded-xl transition-color text-[color-mix(in_oklch,var(--color)_25%,oklch(0%_0_0/80%))] bg-[color-mix(in_oklch,var(--color)_10%,oklch(100%_0_0))] hover:bg-[color-mix(in_oklch,var(--color)_15%,oklch(100%_0_0))] active:bg-[color-mix(in_oklch,var(--color)_20%,oklch(100%_0_0))]"
        , Attributes.attribute "style" ("--color:" ++ tag.color)
        ]
        [ Html.div [ Attributes.class "grid gap-3 items-center mb-3 grid-cols-[auto_1fr]" ]
            [ Html.div
                [ Attributes.class "w-4 h-4 rounded-full"
                , Attributes.style "background-color" tag.color
                ]
                []
            , Html.h3 [ Attributes.class "text-lg font-semibold" ]
                [ Html.a
                    [ Attributes.class "before:absolute before:inset-0 before:rounded-xl"
                    , Route.Path.href (Route.Path.Tags_TagId_ { tagId = tagId })
                    ]
                    [ Html.text tagId ]
                ]
            ]
        , case tag.description of
            Just description ->
                Html.p [ Attributes.class "text-sm text-gray-600" ]
                    [ Html.text description ]

            Nothing ->
                Html.p [ Attributes.class "text-sm italic text-gray-400" ]
                    [ Html.text "No description available" ]
        ]


viewSkeletonContent : Html msg
viewSkeletonContent =
    Html.div [ Attributes.class "grid gap-4 grid-cols-[repeat(auto-fill,minmax(12rem,1fr))]" ]
        (List.repeat 6
            (Html.div [ Attributes.class "p-6 bg-gray-100 rounded-lg animate-pulse" ]
                [ Html.div [ Attributes.class "flex gap-3 items-center mb-3" ]
                    [ Html.div [ Attributes.class "w-4 h-4 bg-gray-300 rounded-full" ] []
                    , Html.div [ Attributes.class "w-20 h-6 bg-gray-300 rounded" ] []
                    ]
                , Html.div [ Attributes.class "w-full h-10 bg-gray-300 rounded" ] []
                ]
            )
        )
