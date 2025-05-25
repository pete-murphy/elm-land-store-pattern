module Pages.Posts exposing (Model, Msg, page)

import Api.Post exposing (Post, Preview)
import Auth
import Auth.Credentials exposing (Credentials)
import Components.Button as Button
import Components.Modal as Modal
import CustomElements
import Dict exposing (Dict)
import Effect exposing (Effect)
import Form
import Form.Field as Field
import Form.FieldView as FieldView
import Form.Validation as Validation
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
    , credentials : Credentials
    , modalIsOpen : Bool
    , formModel : Form.Model
    , formErrors : Dict String (List String)
    , newPost : Data ()
    }


type alias FormErrors =
    Dict String (List String)


init : Auth.User -> Shared.Model -> () -> ( Model, Effect Msg )
init user _ _ =
    ( { posts = Loadable.loading
      , credentials = user.credentials
      , modalIsOpen = False
      , formModel = Form.init
      , formErrors = Dict.empty
      , newPost = Loadable.notAsked
      }
    , Effect.request (Api.Post.list user.credentials { page = 1, limit = 10, status = Nothing, search = Nothing })
        BackendRespondedToGetPosts
    )



-- UPDATE


type alias ApiResult a =
    Result DetailedError a


type Msg
    = BackendRespondedToGetPosts (ApiResult (Paginated (Post Preview)))
    | BackendRespondedToCreatePost (ApiResult (Post Api.Post.Details))
    | UserScrolledToBottom
    | UserClickedCreatePost
    | UserClosedModal
    | UserSubmittedCreatePostForm (Form.Validated String Api.Post.CreatePostRequest)
    | FormMsg (Form.Msg Msg)
    | NoOp


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        BackendRespondedToGetPosts result ->
            ( { model
                | posts =
                    case Loadable.value model.posts of
                        Loadable.Empty ->
                            Loadable.fromResult result

                        _ ->
                            Loadable.succeed Paginated.merge
                                |> Loadable.andMap model.posts
                                |> Loadable.andMap (Loadable.fromResult result)
                                |> Loadable.toNotLoading
              }
            , Effect.none
            )

        BackendRespondedToCreatePost result ->
            case result of
                Ok _ ->
                    ( { model
                        | modalIsOpen = False
                        , formModel = Form.init
                        , formErrors = Dict.empty
                        , newPost = Loadable.succeed ()
                        , posts = Loadable.toLoading model.posts
                      }
                    , Effect.request (Api.Post.list model.credentials { page = 1, limit = 10, status = Nothing, search = Nothing })
                        BackendRespondedToGetPosts
                    )

                Err error ->
                    ( { model | newPost = Loadable.fail error }
                    , Effect.none
                    )

        UserScrolledToBottom ->
            case Loadable.value model.posts of
                Loadable.Success paginatedPosts ->
                    if paginatedPosts.pagination.hasNextPage then
                        ( { model | posts = Loadable.toLoading model.posts }
                        , Effect.request
                            (Api.Post.list model.credentials
                                { page = paginatedPosts.pagination.page + 1
                                , limit = paginatedPosts.pagination.limit
                                , status = Nothing
                                , search = Nothing
                                }
                            )
                            BackendRespondedToGetPosts
                        )

                    else
                        ( model, Effect.none )

                _ ->
                    ( model, Effect.none )

        UserClickedCreatePost ->
            ( { model
                | modalIsOpen = True
                , formErrors = Dict.empty
              }
            , Effect.none
            )

        UserClosedModal ->
            ( { model
                | modalIsOpen = False
                , formErrors = Dict.empty
              }
            , Effect.none
            )

        UserSubmittedCreatePostForm (Form.Valid createPostRequest) ->
            ( { model | newPost = Loadable.loading }
            , Effect.request (Api.Post.create model.credentials createPostRequest)
                BackendRespondedToCreatePost
            )

        UserSubmittedCreatePostForm (Form.Invalid _ errors) ->
            ( { model | formErrors = errors }
            , Effect.none
            )

        FormMsg formMsg ->
            let
                ( updatedFormModel, cmd ) =
                    Form.update formMsg model.formModel
            in
            ( { model | formModel = updatedFormModel }
            , Effect.sendCmd cmd
            )

        NoOp ->
            ( model, Effect.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- FORM


createPostForm : Dict String (List String) -> Form.HtmlForm String Api.Post.CreatePostRequest () msg
createPostForm errors =
    (\title content excerpt status ->
        { combine =
            Validation.succeed
                (\titleVal contentVal excerptVal statusVal ->
                    Api.Post.CreatePostRequest
                        titleVal
                        contentVal
                        excerptVal
                        statusVal
                        []
                )
                |> Validation.andMap title
                |> Validation.andMap content
                |> Validation.andMap excerpt
                |> Validation.andMap
                    (status
                        |> Validation.andThen
                            (\statusString ->
                                case statusString of
                                    "draft" ->
                                        Validation.succeed Api.Post.Draft

                                    "published" ->
                                        Validation.succeed Api.Post.Published

                                    _ ->
                                        Validation.fail "Invalid status" status
                            )
                    )
        , view =
            \context ->
                let
                    fieldView label field attrs =
                        let
                            id =
                                Validation.fieldName field

                            errorForField =
                                Dict.get id errors
                                    |> Maybe.andThen List.head
                        in
                        Html.div [ Attributes.class "grid relative gap-1" ]
                            [ Html.label
                                [ Attributes.class "text-sm font-semibold"
                                , Attributes.for id
                                ]
                                [ Html.text label ]
                            , case errorForField of
                                Just error ->
                                    Html.div
                                        [ Attributes.class "text-sm text-red-500" ]
                                        [ Html.text error ]

                                Nothing ->
                                    Html.text ""
                            , FieldView.input
                                (Attributes.class "py-2 px-4 w-full rounded-lg border border-gray-800 well-focus"
                                    :: Attributes.id id
                                    :: attrs
                                )
                                field
                            ]
                in
                [ fieldView "Title" title []
                , fieldView "Content" content []
                , fieldView "Excerpt" excerpt []
                , fieldView "Status" status []
                , Button.new
                    |> Button.withLoading context.submitting
                    |> Button.withChildren [ Html.text "Create" ]
                    |> Button.toHtml
                ]
        }
    )
        |> Form.form
        |> Form.field "title"
            (Field.text
                |> Field.required "Title is required"
            )
        |> Form.field "content"
            (Field.text
                |> Field.textarea { cols = Nothing, rows = Nothing }
                |> Field.required "Content is required"
            )
        |> Form.field "excerpt"
            (Field.text
                |> Field.textarea { cols = Nothing, rows = Nothing }
            )
        |> Form.field "status"
            (Field.text
                |> Field.withInitialValue (\_ -> "draft")
                |> Field.required "Status is required"
            )



-- VIEW


view : Model -> View Msg
view model =
    { title = "Posts"
    , body =
        [ Html.div [ Attributes.class "flex flex-col gap-6" ]
            [ Html.div [ Attributes.class "flex justify-between items-center" ]
                [ Button.new
                    |> Button.withText "Create Post"
                    |> Button.withOnClick UserClickedCreatePost
                    |> Button.toHtml
                ]
            , viewCreatePostModal model
            , viewPostsSection model.posts
            ]
        ]
    }


viewCreatePostModal : Model -> Html Msg
viewCreatePostModal model =
    Modal.new
        { onClose = UserClosedModal
        , open = model.modalIsOpen
        }
        [ Html.h2 [ Attributes.class "mb-4 text-xl font-bold" ]
            [ Html.text "Create New Post" ]
        , Html.div [ Attributes.class "mb-4" ]
            [ createPostForm model.formErrors
                |> Form.renderHtml
                    { submitting = Loadable.isLoading model.newPost
                    , state = model.formModel
                    , toMsg = FormMsg
                    }
                    (Form.options "new-entry-form"
                        |> Form.withOnSubmit
                            (.parsed >> UserSubmittedCreatePostForm)
                    )
                    [ Attributes.class "grid gap-4" ]
            ]
        ]
        |> Modal.withModifyAttrs
            ((::) (Attributes.class "w-full max-w-xl"))
        |> Modal.toHtml


viewPostsSection : Data (Paginated (Post Preview)) -> Html Msg
viewPostsSection postsData =
    case Loadable.value postsData of
        Loadable.Empty ->
            viewSkeletonContent

        Loadable.Failure error ->
            -- TODO: Show error properly
            Html.text (Debug.toString error)

        Loadable.Success paginatedPosts ->
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
        (List.repeat 4
            (Html.div [ Attributes.class "bg-gray-100 rounded-md animate-pulse min-h-40" ]
                []
            )
        )
