package com.paditech.mvpbase.screen.login;

import android.content.Intent;
import android.os.Bundle;
import android.view.View;
import android.widget.CheckBox;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.mvp.activity.ActivityPresenter;
import com.paditech.mvpbase.common.mvp.activity.MVPActivity;
import com.paditech.mvpbase.common.utils.AnimUtils;
import com.paditech.mvpbase.common.utils.PrefUtil;
import com.paditech.mvpbase.common.utils.StringUtil;
import com.paditech.mvpbase.screen.main.MainActivity;
import com.paditech.mvpbase.screen.register.RegisterActivity;
import com.paditech.mvpbase.screen.term_register.TernRegisterActivity;
import com.paditech.mvpbase.screen.term_register.TernRegisterPresenter;

import butterknife.BindView;
import butterknife.ButterKnife;
import butterknife.OnClick;

/**
 * Created by ThanhNgocHoang on 11/22/2017.
 */

public class LoginActivity extends MVPActivity<LoginContact.PresenterViewOps> implements LoginContact.ViewOps {
    public static final int TYPE_USER = 1;
    public static final int TYPE_PHOTOGRAPHER = 2;
    @BindView(R.id.et_email)
    EditText etEmail;
    @BindView(R.id.et_password)
    EditText etPassword;
    @BindView(R.id.btn_register)
    TextView btnRegister;


    @Override
    protected int getContentView() {
        return R.layout.act_login;
    }

    @Override
    protected void initView() {
        if (PrefUtil.isLogin()) {
            goToHome();
        }
    }

    @Override
    protected Class<? extends ActivityPresenter> onRegisterPresenter() {
        return LoginPresenter.class;
    }

    @Override
    public void goToHome() {
        hideProgressbar();
        Intent intent = new Intent(this, MainActivity.class);
        intent.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_CLEAR_TASK);
        startActivity(intent);
        finish();
    }

    public void goTermView() {
        hideProgressbar();
        Intent intent = new Intent(this, TernRegisterActivity.class);
        intent.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_CLEAR_TASK);
        startActivity(intent);
        finish();
    }

    @Override
    public void onFailed(String message) {
        hideProgressbar();
        if (!StringUtil.isEmpty(message)) showAlertDialog(message);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        getPresenter().onActivityResult(requestCode, resultCode, data);
    }

    @OnClick({R.id.btn_register, R.id.btn_fb, R.id.btn_google, R.id.btn_login})
    public void onViewClicked(View view) {
        switch (view.getId()) {
            case R.id.btn_login:
                if (validate())
                    getPresenter().onLoginNormal(etEmail.getText().toString().trim(), etPassword.getText().toString().trim());
                break;
            case R.id.btn_register:
                startActivity(new Intent(this, RegisterActivity.class));
                break;
            case R.id.btn_fb:
                getPresenter().onFbSignIn(TYPE_USER);
                break;
            case R.id.btn_google:
                getPresenter().onGgSignIn(TYPE_USER);
                break;
        }
    }

    private boolean validate() {
        if (StringUtil.isEmpty(etEmail.getText().toString().trim())) {
            showToast(getString(R.string.mess_email_empty));
            return false;
        }
        if (StringUtil.isEmpty(etPassword.getText().toString().trim())) {
            showToast(getString(R.string.mess_pass_empty));
            return false;
        }
        return true;
    }
}
