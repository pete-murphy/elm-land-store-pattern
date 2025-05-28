module Pages.Tags.TagId_ exposing (Model, Msg, page)

import Api.Post exposing (Post)
import Api.TagId as TagId
import Auth
import Components.IntersectionObservee as IntersectionObservee
import Effect exposing (Effect)
import Html exposing (Html)
import Html.Attributes as Attributes
import Http.DetailedError as DetailedError exposing (DetailedError)
import Http.Extra exposing (Request)
import Layouts
import Loadable exposing (Loadable)
import Page exposing (Page)
import Paginated exposing (Paginated)
import Route exposing (Route)
import Route.Path
import Shared
import Shared.Model
import Store
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { tagId : String } -> Page Model Msg
page user shared route =
    let
        requests : Requests
        requests =
            { posts = Api.Post.listByTag user.credentials (TagId.fromRoute route) { limit = 10 } }
    in
    Page.new
        { init = init requests shared
        , update = update requests shared
        , view = view requests shared route
        , subscriptions = subscriptions
        }
        |> Page.withLayout (toLayout user)


toLayout : Auth.User -> Model -> Layouts.Layout Msg
toLayout user _ =
    Layouts.Authenticated { user = user }



-- INIT


type alias Requests =
    { posts : Request (Paginated (Post Api.Post.Preview))
    }


type alias Model =
    {}


init : Requests -> Shared.Model -> () -> ( Model, Effect Msg )
init requests shared _ =
    ( {}
    , Effect.sendStoreRequestPaginated (Shared.Model.paginatedStrategy shared) requests.posts
    )



-- UPDATE


type Msg
    = UserScrolledToBottom


update : Requests -> Shared.Model -> Msg -> Model -> ( Model, Effect Msg )
update requests shared msg model =
    case msg of
        UserScrolledToBottom ->
            ( model
            , Effect.sendStoreRequestPaginated (Shared.Model.paginatedStrategy shared) requests.posts
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


type alias Data a =
    Loadable DetailedError a


view : Requests -> Shared.Model -> Route { tagId : String } -> Model -> View Msg
view requests shared route model =
    { title = "Posts tagged with \"" ++ route.params.tagId ++ "\""
    , body =
        [ Html.div [ Attributes.class "flex flex-col gap-6" ]
            [ Html.header [ Attributes.class "flex flex-col gap-4" ]
                [ Html.nav [ Attributes.class "text-sm" ]
                    [ Html.a
                        [ Route.Path.href Route.Path.Tags
                        , Attributes.class "text-gray-600 underline"
                        ]
                        [ Html.text "← Back to all tags" ]
                    ]
                , Html.div []
                    [ Html.p [ Attributes.class "mt-2 text-gray-600" ]
                        [ Html.text "Browse all posts in this category." ]
                    ]
                ]
            , viewPostsSection (Store.get requests.posts (Shared.Model.store shared))
            ]
        ]
    }


viewPostsSection : Data (Paginated (Post Api.Post.Preview)) -> Html Msg
viewPostsSection postsData =
    case Loadable.value postsData of
        Loadable.Empty ->
            viewSkeletonContent

        Loadable.Failure error ->
            Html.div [ Attributes.class "p-4 text-red-700 bg-red-50 rounded-lg border border-red-200" ]
                [ Html.text ("Error loading posts: " ++ DetailedError.toString error) ]

        Loadable.Success paginatedPosts ->
            if List.isEmpty paginatedPosts.data then
                Html.div [ Attributes.class "py-12 text-center" ]
                    [ Html.div [ Attributes.class "mb-4 text-4xl text-gray-400" ]
                        [ Html.text "📝" ]
                    , Html.p [ Attributes.class "text-gray-600" ]
                        [ Html.text "No posts found for this tag yet." ]
                    ]

            else
                Html.div [ Attributes.class "flex flex-col gap-4" ]
                    [ Api.Post.viewPreviewList paginatedPosts.data
                    , IntersectionObservee.new UserScrolledToBottom
                        |> IntersectionObservee.withDisabled (Loadable.isLoading postsData)
                        |> IntersectionObservee.toHtml
                    , if Loadable.isLoading postsData then
                        viewSkeletonContent

                      else
                        Html.text ""
                    ]


viewSkeletonContent : Html msg
viewSkeletonContent =
    Html.div [ Attributes.class "flex flex-col gap-6" ]
        (List.repeat 3
            (Html.div [ Attributes.class "bg-gray-100 rounded-md animate-pulse min-h-40" ]
                []
            )
        )
