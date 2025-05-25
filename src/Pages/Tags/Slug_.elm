module Pages.Tags.Slug_ exposing (Model, Msg, page)

import Api.Post exposing (Post)
import Api.Tag exposing (Tag)
import Auth
import Auth.Credentials exposing (Credentials)
import CustomElements
import Effect exposing (Effect)
import Html exposing (Html)
import Html.Attributes as Attributes
import Http.DetailedError as DetailedError exposing (DetailedError)
import Layouts
import Loadable exposing (Loadable)
import Page exposing (Page)
import Paginated exposing (Paginated)
import Route exposing (Route)
import Route.Path
import Shared
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { slug : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init user shared route.params.slug
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
    { tagSlug : String
    , posts : Data (Paginated (Post Api.Post.Preview))
    , credentials : Credentials
    }


init : Auth.User -> Shared.Model -> String -> () -> ( Model, Effect Msg )
init user _ tagSlug _ =
    ( { tagSlug = tagSlug
      , posts = Loadable.loading
      , credentials = user.credentials
      }
    , Effect.request (Api.Post.listByTag user.credentials tagSlug { page = 1, limit = 10 })
        BackendRespondedToGetPosts
    )



-- UPDATE


type alias ApiResult a =
    Result DetailedError a


type Msg
    = BackendRespondedToGetPosts (ApiResult (Paginated (Post Api.Post.Preview)))
    | UserScrolledToBottom


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        BackendRespondedToGetPosts result ->
            ( { model
                | posts =
                    case Result.map (.pagination >> .page) result of
                        Ok 1 ->
                            Loadable.fromResult result

                        _ ->
                            Loadable.succeed Paginated.merge
                                |> Loadable.andMap model.posts
                                |> Loadable.andMap (Loadable.fromResult result)
                                |> Loadable.toNotLoading
              }
            , Effect.none
            )

        UserScrolledToBottom ->
            case Loadable.value model.posts of
                Loadable.Success paginatedPosts ->
                    if paginatedPosts.pagination.hasNextPage then
                        ( { model | posts = Loadable.toLoading model.posts }
                        , Effect.request
                            (Api.Post.listByTag model.credentials
                                model.tagSlug
                                { page = paginatedPosts.pagination.page + 1
                                , limit = paginatedPosts.pagination.limit
                                }
                            )
                            BackendRespondedToGetPosts
                        )

                    else
                        ( model, Effect.none )

                _ ->
                    ( model, Effect.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Model -> View Msg
view model =
    { title = "Posts tagged with \"" ++ model.tagSlug ++ "\""
    , body =
        [ Html.div [ Attributes.class "flex flex-col gap-6" ]
            [ Html.header [ Attributes.class "flex flex-col gap-4" ]
                [ Html.nav [ Attributes.class "text-sm" ]
                    [ Html.a
                        [ Route.Path.href Route.Path.Tags
                        , Attributes.class "text-blue-600 hover:underline"
                        ]
                        [ Html.text "← Back to all tags" ]
                    ]
                , Html.div []
                    [ Html.h1 [ Attributes.class "text-3xl font-bold" ]
                        [ Html.text ("Posts tagged with \"" ++ model.tagSlug ++ "\"") ]
                    , Html.p [ Attributes.class "text-gray-600 mt-2" ]
                        [ Html.text "Browse all posts in this category." ]
                    ]
                ]
            , viewPostsSection model.posts
            ]
        ]
    }


viewPostsSection : Data (Paginated (Post Api.Post.Preview)) -> Html Msg
viewPostsSection postsData =
    case Loadable.value postsData of
        Loadable.Empty ->
            viewSkeletonContent

        Loadable.Failure error ->
            Html.div [ Attributes.class "p-4 bg-red-50 border border-red-200 rounded-lg text-red-700" ]
                [ Html.text ("Error loading posts: " ++ DetailedError.toString error) ]

        Loadable.Success paginatedPosts ->
            if List.isEmpty paginatedPosts.data then
                Html.div [ Attributes.class "text-center py-12" ]
                    [ Html.div [ Attributes.class "text-gray-400 mb-4 text-4xl" ]
                        [ Html.text "📝" ]
                    , Html.p [ Attributes.class "text-gray-600" ]
                        [ Html.text "No posts found for this tag yet." ]
                    ]

            else
                Html.div [ Attributes.class "flex flex-col gap-4" ]
                    [ Api.Post.viewPreviewList paginatedPosts.data
                    , CustomElements.intersectionSentinel
                        { onIntersect = UserScrolledToBottom
                        , disabled = Loadable.isLoading postsData
                        }
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
