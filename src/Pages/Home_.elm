module Pages.Home_ exposing (Data, Model, Msg, page)

import Api.Post as Post exposing (Post)
import Api.Tag as Tag exposing (Tag)
import Api.User as User exposing (User)
import Auth
import Effect exposing (Effect)
import Html exposing (Html)
import Html.Attributes as Attributes
import Http.DetailedError as DetailedError exposing (DetailedError)
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
    { tags : Data (List Tag)
    , users : Data (List (User User.Preview))
    , posts : Data (List (Post Post.Preview))
    }


init : Auth.User -> Shared.Model -> () -> ( Model, Effect Msg )
init user _ _ =
    ( { tags = Loadable.loading
      , users = Loadable.loading
      , posts = Loadable.loading
      }
    , Effect.batch
        [ Effect.request (Tag.get user.credentials)
            BackendRespondedToGetTags
        , Effect.request (User.list user.credentials { page = 1, limit = 5 })
            BackendRespondedToGetUsers
        , Effect.request (Post.list user.credentials { limit = 5, status = Nothing, search = Nothing })
            BackendRespondedToGetPosts
        ]
    )



-- UPDATE


type alias ApiResult a =
    Result DetailedError a


type Msg
    = BackendRespondedToGetTags (ApiResult (List Tag))
    | BackendRespondedToGetUsers (ApiResult (Paginated (User User.Preview)))
    | BackendRespondedToGetPosts (ApiResult (Paginated (Post Post.Preview)))
    | NoOp


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        BackendRespondedToGetTags result ->
            ( { model | tags = Loadable.fromResult result }
            , Effect.none
            )

        BackendRespondedToGetUsers result ->
            ( { model | users = Loadable.fromResult (result |> Result.map .data) }
            , Effect.none
            )

        BackendRespondedToGetPosts result ->
            ( { model | posts = Loadable.fromResult (result |> Result.map .data) }
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
    { title = "Home"
    , body =
        [ Html.div [ Attributes.class "flex flex-col gap-6" ]
            [ viewSection
                { title = "Tags"
                , apiData = model.tags
                , view = Tag.viewList
                }
            , viewSection
                { title = "Users"
                , apiData = model.users
                , view = User.viewPreviewList
                }
            , viewSection
                { title = "Posts"
                , apiData = model.posts
                , view = Post.viewPreviewList
                }
            ]
        ]
    }


viewSection : { title : String, apiData : Data a, view : a -> Html msg } -> Html msg
viewSection props =
    Html.section [ Attributes.class "flex flex-col gap-4" ]
        [ Html.h2 [ Attributes.class "text-xl font-bold" ]
            [ Html.text props.title ]
        , case Loadable.value props.apiData of
            Loadable.Empty ->
                viewSkeletonSectionContent

            Loadable.Failure error ->
                Html.text (DetailedError.toString error)

            Loadable.Success value ->
                props.view value
        ]


viewSkeletonSectionContent : Html msg
viewSkeletonSectionContent =
    Html.div [ Attributes.class "flex flex-col gap-4 p-4 bg-gray-100 rounded-md animate-pulse min-h-40" ]
        []
