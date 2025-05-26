module Pages.Tags.TagId_ exposing (Model, Msg, page)

import Api.Post exposing (Post)
import Api.TagId as TagId
import Auth
import Components.IntersectionObservee as IntersectionObservee
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


page : Auth.User -> Shared.Model -> Route { tagId : String } -> Page Model Msg
page user _ route =
    Page.new
        { init = init user route
        , update = update user route
        , view = view route
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
    { posts : Data (Paginated (Post Api.Post.Preview))
    }


init : Auth.User -> Route { tagId : String } -> () -> ( Model, Effect Msg )
init user route _ =
    let
        tagId =
            TagId.fromRoute route
    in
    ( { posts = Loadable.loading }
    , Effect.request (Api.Post.listByTag user.credentials tagId { page = 1, limit = 10 })
        BackendRespondedToGetPosts
    )



-- UPDATE


type alias ApiResult a =
    Result DetailedError a


type Msg
    = BackendRespondedToGetPosts (ApiResult (Paginated (Post Api.Post.Preview)))
    | UserScrolledToBottom


update : Auth.User -> Route { tagId : String } -> Msg -> Model -> ( Model, Effect Msg )
update user route msg model =
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
                            (Api.Post.listByTag user.credentials
                                (TagId.fromRoute route)
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


view : Route { tagId : String } -> Model -> View Msg
view route model =
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
