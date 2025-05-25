module Pages.Posts exposing (Model, Msg, page)

import Api.Post exposing (Post, Preview)
import Auth
import Effect exposing (Effect)
import Html exposing (Html)
import Html.Attributes as Attributes
import Http.DetailedError exposing (DetailedError)
import Layouts
import Loadable exposing (Loadable)
import Page exposing (Page)
import Paginated exposing (Paginated)
import Route exposing (Route)
import Shared
import View exposing (View)


page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
page user shared _ =
    Page.new
        { init = init user shared
        , update = update
        , view = view
        , subscriptions = subscriptions
        }
        |> Page.withLayout (toLayout user)


toLayout : Auth.User -> Model -> Layouts.Layout Msg
toLayout user _ =
    Layouts.Authenticated { user = user }



-- INIT


type alias Data a =
    Loadable DetailedError a


type alias Model =
    { posts : Data (Paginated (Post Preview))
    }


init : Auth.User -> Shared.Model -> () -> ( Model, Effect Msg )
init user _ _ =
    ( { posts = Loadable.loading
      }
    , Effect.request (Api.Post.list user.credentials { page = 1, limit = 10, status = Nothing, search = Nothing })
        BackendRespondedToGetPosts
    )



-- UPDATE


type alias ApiResult a =
    Result DetailedError a


type Msg
    = BackendRespondedToGetPosts (ApiResult (Paginated (Post Preview)))
    | NoOp


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        BackendRespondedToGetPosts result ->
            ( { model | posts = Loadable.fromResult result }
            , Effect.none
            )

        NoOp ->
            ( model, Effect.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Model -> View Msg
view model =
    { title = "Posts"
    , body =
        [ Html.div [ Attributes.class "flex flex-col gap-6" ]
            [ viewPostsSection model.posts
            ]
        ]
    }


viewPostsSection : Data (Paginated (Post Preview)) -> Html Msg
viewPostsSection postsData =
    case Loadable.value postsData of
        Loadable.Empty ->
            viewSkeletonContent

        Loadable.Failure error ->
            -- TODO: Show error properly
            Html.text (Debug.toString error)

        Loadable.Success paginatedPosts ->
            Api.Post.viewPreviewList paginatedPosts.data


viewSkeletonContent : Html msg
viewSkeletonContent =
    Html.div [ Attributes.class "flex flex-col gap-4 p-4 bg-gray-100 rounded-md min-h-40" ]
        []
