package com.paditech.mvpbase.screen.login;

import android.annotation.SuppressLint;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.pm.Signature;
import android.provider.Settings;
import androidx.annotation.NonNull;
import androidx.fragment.app.FragmentActivity;
import android.util.Base64;
import android.util.Log;

import com.facebook.AccessToken;
import com.facebook.CallbackManager;
import com.facebook.FacebookCallback;
import com.facebook.FacebookException;
import com.facebook.login.LoginManager;
import com.facebook.login.LoginResult;
import com.google.android.gms.auth.api.signin.GoogleSignIn;
import com.google.android.gms.auth.api.signin.GoogleSignInClient;
import com.google.android.gms.auth.api.signin.GoogleSignInAccount;
import com.google.android.gms.auth.api.signin.GoogleSignInOptions;
import com.google.android.gms.common.api.ApiException;
import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.Task;
import com.google.firebase.auth.AuthCredential;
import com.google.firebase.auth.AuthResult;
import com.google.firebase.auth.FacebookAuthProvider;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseUser;
import com.google.firebase.auth.GoogleAuthProvider;
import com.google.firebase.database.FirebaseDatabase;
import com.google.firebase.firestore.DocumentSnapshot;
import com.google.firebase.firestore.FirebaseFirestore;
import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.model.Device;
import com.paditech.mvpbase.common.model.User;
import com.paditech.mvpbase.common.mvp.activity.ActivityPresenter;
import com.paditech.mvpbase.common.utils.PrefUtil;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Arrays;
import java.util.List;

/**
 * Created by ThanhNgocHoang on 11/22/2017.
 */

public class LoginPresenter extends ActivityPresenter<LoginContact.ViewOps>
        implements LoginContact.PresenterViewOps {
    private final String TAG = LoginActivity.class.getSimpleName();
    private final int RC_SIGN_IN = 100;

    private GoogleSignInClient mGoogleSignInClient;
    private FirebaseAuth mAuth;
    private FirebaseAuth.AuthStateListener mAuthListener;
    private CallbackManager mCallbackManager;
    private int currentType;

    @Override
    public void onCreate() {
        super.onCreate();
        setupFirebase();
        setupGoogle();
        getKeyHash();
    }

    @Override
    public void onResume() {
        super.onResume();
        mAuth.addAuthStateListener(mAuthListener);
    }

    @Override
    public void onPause() {
        if (mAuthListener != null) {
            mAuth.removeAuthStateListener(mAuthListener);
        }
        super.onPause();
    }

    private void setupFirebase() {
        mAuth = FirebaseAuth.getInstance();
        mAuthListener = new FirebaseAuth.AuthStateListener() {
            @Override
            public void onAuthStateChanged(@NonNull FirebaseAuth firebaseAuth) {
                FirebaseUser user = firebaseAuth.getCurrentUser();
                if (user != null) {
                    // User is signed in
                } else {
                    // User is signed out
                }
            }
        };
    }

    private void setupGoogle() {
        GoogleSignInOptions gso = new GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
                .requestIdToken(getView().getActivityContext().getString(R.string.default_web_client_id))
                .requestEmail()
                .build();

        mGoogleSignInClient = GoogleSignIn.getClient(getView().getActivityContext(), gso);
    }

    @SuppressLint("PackageManagerGetSignatures")
    private void getKeyHash() {
        PackageInfo info;
        try {
            info = getView().getActivityContext().getPackageManager().getPackageInfo
                    (getView().getActivityContext().getPackageName(), PackageManager.GET_SIGNATURES);
            for (Signature signature : info.signatures) {
                MessageDigest md;
                md = MessageDigest.getInstance("SHA");
                md.update(signature.toByteArray());
                String something = new String(Base64.encode(md.digest(), 0));
                //String something = new String(Base64.encodeBytes(md.digest()));
                Log.e("hash key", something);
            }
        } catch (PackageManager.NameNotFoundException e1) {
            Log.e("name not found", e1.toString());
        } catch (NoSuchAlgorithmException e) {
            Log.e("no such an algorithm", e.toString());
        } catch (Exception e) {
            Log.e("exception", e.toString());
        }
    }

    @Override
    public void onFbSignIn(int type) {
        // request dang nhap Facebook
        getView().showProgressbar();
        currentType = type;
        mCallbackManager = CallbackManager.Factory.create();
        List<String> permissionNeeds = Arrays.asList("email", "public_profile");
        LoginManager.getInstance().logInWithReadPermissions(getView().getActivity(), permissionNeeds);
        LoginManager.getInstance().registerCallback(mCallbackManager, new FacebookCallback<LoginResult>() {
            @Override
            public void onSuccess(LoginResult loginResult) {
                Log.d(TAG, "facebook:onSuccess:" + loginResult);
                handleFacebookAccessToken(loginResult.getAccessToken());
            }

            @Override
            public void onCancel() {
                Log.d(TAG, "facebook:onCancel");
                getView().hideProgressbar();
                // ...
            }

            @Override
            public void onError(FacebookException error) {
                Log.d(TAG, "facebook:onError", error);
                getView().hideProgressbar();
                // ...
            }
        });
    }

    private void handleFacebookAccessToken(AccessToken token) {
        Log.d(TAG, "handleFacebookAccessToken:" + token);
        //  login facebook thanh cong ==> gui credential của FB len Firebase
        AuthCredential credential = FacebookAuthProvider.getCredential(token.getToken());
        mAuth.signInWithCredential(credential)
                .addOnCompleteListener(getView().getActivity(), new OnCompleteListener<AuthResult>() {
                    @Override
                    public void onComplete(@NonNull Task<AuthResult> task) {
                        Log.d(TAG, "signInWithCredential:onComplete:" + task.isSuccessful());

                        // If sign in fails, display a message to the user_id. If sign in succeeds
                        // the auth state listener will be notified and logic to handle the
                        // signed in user_id can be handled in the listener.
                        if (!task.isSuccessful()) {
                            Log.w(TAG, "signInWithCredential", task.getException());
                            getView().onFailed(task.getException().getMessage());
                            getView().hideProgressbar();
                        } else {
                            FirebaseUser firebaseUser = task.getResult().getUser();
                            if (firebaseUser != null) {
                                // bo phan check này đi, mặc định userType = user_id
                                User user = new User();
                                user.setId(firebaseUser.getUid());
                                user.setFull_name(firebaseUser.getDisplayName());
                                user.setMail_address(firebaseUser.getEmail());
                                if (firebaseUser.getPhotoUrl() != null)
                                    user.setAvatar(firebaseUser.getPhotoUrl().toString());
                                //Cất dữ liệu
                                saveUser(user);
                            }
                        }
                    }
                });
    }


    @Override
    public void onGgSignIn(int type) {
        // request login bằng GG
        getView().showProgressbar();
        currentType = type;
        Intent signInIntent = mGoogleSignInClient.getSignInIntent();
        getView().getActivity().startActivityForResult(signInIntent, RC_SIGN_IN);
    }

    @Override
    public void onLoginNormal(String email, String password) {
        try {
            // login binh thường bằng email password
            getView().showProgressbar();
            mAuth.signInWithEmailAndPassword(email, password).addOnCompleteListener(new OnCompleteListener<AuthResult>() {
                @Override
                public void onComplete(@NonNull Task<AuthResult> task) {
                    getView().hideProgressbar();
                    if (task.isSuccessful()) {
                        FirebaseUser firebaseUser = task.getResult().getUser();

                        User user = new User();
                        user.setId(firebaseUser.getUid());
                        user.setFull_name(firebaseUser.getDisplayName());
                        user.setMail_address(firebaseUser.getEmail());
                        if (firebaseUser.getPhotoUrl() != null)
                            user.setAvatar(firebaseUser.getPhotoUrl().toString());
                        PrefUtil.saveUser(getView().getActivityContext(), user);
                        // Mới sửa luồng đăng nhập
                        getView().goToHome();
                    } else {
                        if (task.getException() != null)
                            getView().onFailed(task.getException().getMessage());
                    }
                }
            });
        } catch (Exception e) {
            getView().hideProgressbar();
            e.printStackTrace();
        }
    }

    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == RC_SIGN_IN) {
            Task<GoogleSignInAccount> task = GoogleSignIn.getSignedInAccountFromIntent(data);
            try {
                // Google Sign In was successful, authenticate with Firebase
                GoogleSignInAccount account = task.getResult(ApiException.class);
                firebaseAuthWithGoogle(account);
            } catch (ApiException e) {
                Log.w(TAG, "Google sign in failed", e);
                getView().hideProgressbar();
            }
        } else {
            mCallbackManager.onActivityResult(requestCode, resultCode, data);
        }
    }

    private void firebaseAuthWithGoogle(GoogleSignInAccount acct) {
        Log.d(TAG, "firebaseAuthWithGoogle:" + acct.getId());

        AuthCredential credential = GoogleAuthProvider.getCredential(acct.getIdToken(), null);
        mAuth.signInWithCredential(credential)
                .addOnCompleteListener(getView().getActivity(), new OnCompleteListener<AuthResult>() {
                    @Override
                    public void onComplete(@NonNull Task<AuthResult> task) {
                        Log.d(TAG, "signInWithCredential:onComplete:" + task.isSuccessful());

                        // If sign in fails, display a message to the user_id. If sign in succeeds
                        // the auth state listener will be notified and logic to handle the
                        // signed in user_id can be handled in the listener.
                        try {
                            if (!task.isSuccessful()) {
                                Log.w(TAG, "signInWithCredential", task.getException());
                                getView().onFailed(task.getException().getMessage());
                                getView().hideProgressbar();
                            } else {
                                FirebaseUser firebaseUser = task.getResult().getUser();
                                if (firebaseUser != null) {

                                    User user = new User();
                                    user.setId(firebaseUser.getUid());
                                    user.setFull_name(firebaseUser.getDisplayName());
                                    user.setMail_address(firebaseUser.getEmail());
                                    if (firebaseUser.getPhotoUrl() != null)
                                        user.setAvatar(firebaseUser.getPhotoUrl().toString());
                                    //Cất dữ liệu
                                    saveUser(user);

                                }
                            }
                        } catch (Exception e) {
                            e.printStackTrace();
                            getView().hideProgressbar();
                        }

                    }
                });
    }



    //hàm trả về true nếu là đã tồn tại trong dữ liệu
    void saveUser(final User user) {

        try {

            // hàm để check xem user_id này có tồn tại hay không
            FirebaseFirestore.getInstance().collection("users").document(user.getId()).get().addOnCompleteListener(new OnCompleteListener<DocumentSnapshot>() {
                @Override
                public void onComplete(@NonNull Task<DocumentSnapshot> task) {
                    if (task.isSuccessful()) {
                        if (task.getResult() != null && task.getResult().exists()) {
                            //có tồn tại
                            User userResult = task.getResult().toObject(User.class);
                            userResult.setId(user.getId());
                            PrefUtil.saveUser(getView().getActivityContext(), userResult);
                            // Da co thong tin trong bang User ==> Mo vao ma home
                            getView().goToHome();
                        } else {
                            // k tồn tại
                            PrefUtil.saveUser(getView().getActivityContext(), user);
                            FirebaseFirestore.getInstance().collection("users").document(user.getId()).set(user);
                            Device device = new Device(getView().getActivityContext());
                            FirebaseDatabase.getInstance().getReference().child("user_devices").child(user.getId()).setValue(device);
                            //Xu ly phan login lan dau tien, chua co thong tin trong bảng Users. ==> Mở đến màn Register
                            getView().goTermView();
                        }
                    }
                }
            });
        } catch (Exception e) {
            e.printStackTrace();
        }

    }


}
