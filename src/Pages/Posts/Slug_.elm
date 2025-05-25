module Pages.Posts.Slug_ exposing (Model, Msg, page)

import Api.Post exposing (Post)
import Api.Slug as Slug
import Api.Tag as Tag
import Api.User as User
import Auth
import Components.LocaleTime as LocaleTime
import Effect exposing (Effect)
import Html exposing (Html)
import Html.Attributes as Attributes
import Http.DetailedError exposing (DetailedError)
import Layouts
import Loadable exposing (Loadable)
import Page exposing (Page)
import Route exposing (Route)
import Shared
import View exposing (View)


page : Auth.User -> Shared.Model -> Route { slug : String } -> Page Model Msg
page user shared route =
    Page.new
        { init = init user route
        , update = update
        , subscriptions = subscriptions
        , view = view
        }
        |> Page.withLayout (toLayout user)


toLayout : Auth.User -> Model -> Layouts.Layout Msg
toLayout user _ =
    Layouts.Authenticated { user = user }



-- INIT


type alias Data a =
    Loadable DetailedError a


type alias Model =
    { post : Data (Post Api.Post.Details)
    }


init : Auth.User -> Route { slug : String } -> () -> ( Model, Effect Msg )
init user route () =
    let
        slug =
            Slug.fromRoute route
    in
    ( { post = Loadable.loading
      }
    , Effect.request (Api.Post.get user.credentials slug)
        BackendRespondedToGetPost
    )



-- UPDATE


type alias ApiResult a =
    Result DetailedError a


type Msg
    = BackendRespondedToGetPost (ApiResult (Post Api.Post.Details))
    | NoOp


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        BackendRespondedToGetPost result ->
            ( { model | post = Loadable.fromResult result }
            , Effect.none
            )

        NoOp ->
            ( model
            , Effect.none
            )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- VIEW


view : Model -> View Msg
view model =
    case Loadable.value model.post of
        Loadable.Empty ->
            { title = "Loading..."
            , body = [ viewSkeletonContent ]
            }

        Loadable.Failure error ->
            { title = "Error"
            , body =
                [ Html.div [ Attributes.class "p-4 bg-red-50 rounded-md" ]
                    [ Html.h2 [ Attributes.class "text-lg font-semibold text-red-800 mb-2" ]
                        [ Html.text "Error loading post" ]
                    , Html.p [ Attributes.class "text-red-700" ]
                        [ Html.text (Http.DetailedError.toString error) ]
                    ]
                ]
            }

        Loadable.Success post ->
            { title = Api.Post.title post
            , body = [ viewPost post ]
            }


viewPost : Post Api.Post.Details -> Html Msg
viewPost post =
    Html.article [ Attributes.class "flex flex-col gap-6" ]
        [ Html.header []
            [ Html.div [ Attributes.class "flex gap-2 items-center text-sm text-gray-600 mb-4" ]
                [ Html.text ("by " ++ username (Api.Post.author post))
                , Html.text " • "
                , Html.text (Api.Post.statusToString (Api.Post.status post))
                , Html.text " • "
                , Html.text (String.fromInt (Api.Post.viewCount post) ++ " views")
                ]
            , Html.div [ Attributes.class "flex gap-1 text-sm text-gray-500 mb-6" ]
                (LocaleTime.new (Api.Post.createdAt post)
                    |> LocaleTime.withTimeStyle Nothing
                    |> LocaleTime.withLocaleAttrs []
                    |> LocaleTime.withRelativeAttrs []
                    |> LocaleTime.toHtml
                    |> List.intersperse (Html.text " • ")
                )
            ]
        , Html.div [ Attributes.class "prose max-w-none" ]
            [ Html.p [ Attributes.class "text-lg text-gray-700 mb-6" ]
                [ Html.text (Api.Post.excerpt post) ]
            , Html.div [ Attributes.class "whitespace-pre-wrap text-gray-900" ]
                [ Html.text (Api.Post.content post) ]
            ]
        , Html.footer []
            [ if List.isEmpty (Api.Post.tags post) then
                Html.text ""

              else
                Html.div [ Attributes.class "pt-6 border-t border-gray-200" ]
                    [ Html.h3 [ Attributes.class "text-sm font-semibold text-gray-600 mb-3" ]
                        [ Html.text "Tags" ]
                    , Tag.viewList (Api.Post.tags post)
                    ]
            ]
        ]


viewSkeletonContent : Html msg
viewSkeletonContent =
    Html.div [ Attributes.class "flex flex-col gap-6" ]
        [ Html.div [ Attributes.class "animate-pulse" ]
            [ Html.div [ Attributes.class "h-8 bg-gray-200 rounded mb-4" ] []
            , Html.div [ Attributes.class "h-4 bg-gray-200 rounded mb-2 w-1/2" ] []
            , Html.div [ Attributes.class "h-4 bg-gray-200 rounded mb-6 w-1/3" ] []
            , Html.div [ Attributes.class "h-4 bg-gray-200 rounded mb-2" ] []
            , Html.div [ Attributes.class "h-4 bg-gray-200 rounded mb-2" ] []
            , Html.div [ Attributes.class "h-4 bg-gray-200 rounded mb-2 w-3/4" ] []
            ]
        ]


username : User.User User.Preview -> String
username (User.User internals _) =
    internals.username
