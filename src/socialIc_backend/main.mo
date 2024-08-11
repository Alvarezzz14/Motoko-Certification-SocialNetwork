import Time "mo:base/Time";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Result "mo:base/Result";

actor SocialIC_backend {

    type Profile = {
        id: Principal;
        username: Text;
        bio: Text;
    };

    type Post = {
        id: Nat;
        author: Principal;
        content: Text;
        timestamp: Int;
        comments: [Nat];  // Lista de IDs de comentarios asociados con este post
    };

    type FollowRequest = {
        follower: Principal;
        followee: Principal;
        accepted: Bool;
    };

    type Comment = {
        id: Nat;
        postId: Nat;
        author: Principal;
        content: Text;
        timestamp: Int;
    };

    stable var commentsArray : [Comment] = [];
    var nextCommentId : Nat = 0;

    stable var followRequests : [FollowRequest] = [];

    stable var profilesArray : [Profile] = [];  // Almacén para los perfiles
    var profilesMap : HashMap.HashMap<Principal, Profile> = HashMap.HashMap(5, Principal.equal, Principal.hash);

    stable var postsArray: [Post] = [];
    var nextPostId : Nat = 0; // ID Incremental para los posts 

    // Cargar el HashMap desde el Array estable cuando el canister se inicia
    public func init() {
        for (profile in profilesArray.vals()) {
            profilesMap.put(profile.id, profile);
        }
    };

    public shared(msg: { caller: Principal }) func createProfile(username: Text, bio: Text) : async Result.Result<Text, Text> {
        if (Principal.isAnonymous(msg.caller)) {
            return #err("No se permite crear perfil para usuarios anónimos");
        } else {
            let newProfile : Profile = {
                id = msg.caller;
                username = username;
                bio = bio;
            };
            
            profilesMap.put(msg.caller, newProfile);  // Guardar en HashMap para acceso rápido
            profilesArray := Array.append(profilesArray, [newProfile]);  // Guardar en el Array estable
            return #ok("Perfil creado con éxito");
        };
    };

    public query func getAllProfiles() : async [Profile] {
        return profilesArray;  // Devolver el Array estable con todos los usuarios
    };

    public query(msg) func getMyProfile() : async ?Profile {
        return profilesMap.get(msg.caller);  // Devolver el perfil del HashMap del principal 
    };

    public query(msg) func whoAmI() : async Principal {
        return msg.caller;
    };

    public shared(msg: { caller: Principal }) func editProfile(newUsername: Text, newBio: Text) : async Result.Result<Text, Text> {
        let maybeProfile = profilesMap.get(msg.caller);

        switch maybeProfile {
            case (?profile) {
                let updatedProfile : Profile = {
                    id = profile.id;
                    username = newUsername;
                    bio = newBio;
                };

                profilesMap.put(msg.caller, updatedProfile);

                profilesArray := Array.map<Profile, Profile>(profilesArray, func(p: Profile) : Profile {
                    if (p.id == msg.caller) {
                        updatedProfile;
                    } else {
                        p;
                    }
                });

                return #ok("Perfil actualizado exitosamente");
            };
            case null {
                return #err("Perfil no encontrado");
            };
        }
    };

    public shared(msg: { caller: Principal }) func createPost(content: Text) : async Result.Result<Text, Text> {
        if (content == "") {
            return #err("El contenido del post no puede estar vacío");
        };

        let newPost : Post = {
            id = nextPostId;
            author = msg.caller;
            content = content;
            timestamp = Time.now();
            comments = [];
        };

        postsArray := Array.append(postsArray, [newPost]);
        nextPostId += 1;

        return #ok("Post creado con éxito");
    };

    public query func getAllPosts() : async [Post] {
        return postsArray;
    };

    public query(msg) func getMyPosts() : async [Post] {
        return Array.filter(postsArray, func(post: Post) : Bool { post.author == msg.caller });
    };

    public shared(msg: { caller: Principal }) func editPost(postId: Nat, newContent: Text) : async Result.Result<Text, Text> {
        var postEdited = false;

        postsArray := Array.map<Post, Post>(postsArray, func(post: Post) : Post {
            if (post.id == postId and post.author == msg.caller) {
                postEdited := true;  // Indicamos que el post fue editado
                { id = post.id;
                author = post.author;
                content = newContent;
                timestamp = Time.now();
                comments = post.comments};
            } else {
                post
            }
        });

        if (postEdited) {
            return #ok("Post actualizado con éxito");
        } else {
            return #err("Post no encontrado o no tienes permiso para editarlo");
        };
    };

    public shared(msg: { caller: Principal }) func deletePost(postId: Nat) : async Result.Result<Text, Text> {
        var postDeleted = false;

        // Filtramos los posts y eliminamos el que coincida con el postId y el autor sea el caller
        postsArray := Array.filter(postsArray, func(post: Post) : Bool {
            if (post.id == postId and post.author == msg.caller) {
                postDeleted := true;
                false  // No incluimos este post en el array resultante, lo eliminamos
            } else {
                true  // Mantenemos el post en el array
            }
        });

        if (postDeleted) {
            return #ok("Post eliminado con éxito");
        } else {
            return #err("Post no encontrado o no tienes permiso para eliminarlo");
        };
    };

    public shared(msg: { caller: Principal }) func sendFollowRequest(followee: Principal) : async Result.Result<Text, Text> {
        let request : FollowRequest = {
            follower = msg.caller;
            followee = followee;
            accepted = false;
        };

        followRequests := Array.append(followRequests, [request]);

        return #ok("Solicitud de seguimiento enviada");
    };

    public shared(msg: { caller: Principal }) func acceptFollowRequest(follower: Principal) : async Result.Result<Text, Text> {
        var requestAccepted = false;

        followRequests := Array.map<FollowRequest, FollowRequest>(followRequests, func(request: FollowRequest) : FollowRequest {
            if (request.follower == follower and request.followee == msg.caller and not request.accepted) {
                requestAccepted := true;
                { follower = request.follower; followee = request.followee; accepted = true }
            } else {
                request
            }
        });

        if (requestAccepted) {
            return #ok("Solicitud de seguimiento aceptada");
        } else {
            return #err("Solicitud de seguimiento no encontrada o ya aceptada");
        };
    };

    public shared(msg: { caller: Principal }) func createComment(postId: Nat, content: Text) : async Result.Result<Text, Text> {
        let maybePost = Array.find(postsArray, func(post: Post) : Bool {
            post.id == postId
        });

        switch maybePost {
            case (?post) {
                let isFolloweeOrAuthor = (Array.find(followRequests, func(request: FollowRequest) : Bool {
                    request.follower == msg.caller and request.accepted and request.followee == post.author
                }) != null) or post.author == msg.caller;

                if (isFolloweeOrAuthor) {
                    let newComment : Comment = {
                        id = nextCommentId;
                        postId = postId;
                        author = msg.caller;
                        content = content;
                        timestamp = Time.now();
                    };

                    commentsArray := Array.append(commentsArray, [newComment]);  // Guardamos el comentario
                    nextCommentId += 1;

                    // Añadimos el ID del comentario al post correspondiente
                    postsArray := Array.map<Post, Post>(postsArray, func(p: Post) : Post {
                        if (p.id == postId) {
                            { id = p.id; author = p.author; content = p.content; timestamp = p.timestamp; comments = Array.append(p.comments, [newComment.id]) }
                        } else {
                            p
                        }
                    });

                    return #ok("Comentario creado con éxito");
                } else {
                    return #err("No tienes permiso para comentar en este post");
                }
            };
            case null {
                return #err("Post no encontrado");
            };
        };
    };

    // Función para obtener los posts de los usuarios a los que el usuario autenticado sigue
    public query(msg) func getFolloweesPosts() : async [Post] {
        let myFollowees = Array.filter(followRequests, func(request: FollowRequest) : Bool {
            request.follower == msg.caller and request.accepted
        });

        var posts : [Post] = [];
        for (followeeRequest in myFollowees.vals()) {
            let followeePosts = Array.filter(postsArray, func(post: Post) : Bool {
                post.author == followeeRequest.followee
            });
            posts := Array.append(posts, followeePosts);
        };
        return posts;
    };

    // Función para ver los usuarios que el usuario principal sigue
    public query(msg) func getFollowees() : async [Principal] {
        let followees = Array.filter<FollowRequest>(followRequests, func(request: FollowRequest) : Bool {
            request.follower == msg.caller and request.accepted
        });

        return Array.map<FollowRequest, Principal>(followees, func(request: FollowRequest) : Principal {
            request.followee
        });
    };

    // Función para ver los usuarios que me siguen
    public query(msg) func getFollowers() : async [Principal] {
        let followers = Array.filter<FollowRequest>(followRequests, func(request: FollowRequest) : Bool {
            request.followee == msg.caller and request.accepted
        });

        return Array.map<FollowRequest, Principal>(followers, func(request: FollowRequest) : Principal {
            request.follower
        });
    };

    // Función para obtener los comentarios de un post específico
    public query func getComments(postId: Nat) : async [Comment] {
        let maybePost = Array.find(postsArray, func(post: Post) : Bool {
            post.id == postId
        });

        switch maybePost {
            case (?post) {
                return Array.filter(commentsArray, func(comment: Comment) : Bool {
                    Array.indexOf<Nat>(comment.id, post.comments, func(x, y) { x == y }) != null
                });
            };
            case null {
                return [];  // Si no se encuentra el post, retornamos una lista vacía...
            };
        };
    };
}
