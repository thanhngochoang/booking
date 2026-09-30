package com.paditech.mvpbase.screen.register;

import android.content.Intent;
import android.widget.CheckBox;
import android.widget.EditText;

import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.mvp.activity.ActivityPresenter;
import com.paditech.mvpbase.common.mvp.activity.MVPActivity;
import com.paditech.mvpbase.common.utils.StringUtil;
import com.paditech.mvpbase.screen.main.MainActivity;
import com.paditech.mvpbase.screen.term_register.TernRegisterActivity;

import butterknife.BindView;
import butterknife.OnClick;

/**
 * Created by ThanhNgocHoang on 12/3/2017.
 */

public class RegisterActivity extends MVPActivity<RegisterContact.PresenterViewOps> implements RegisterContact.ViewOps {
    @BindView(R.id.et_email)
    EditText etEmail;
    @BindView(R.id.et_password)
    EditText etPassword;
    @BindView(R.id.et_password_confirm)
    EditText etPasswordConfirm;

    @Override
    protected int getContentView() {
        return R.layout.act_register;
    }

    @Override
    protected void initView() {

    }

    @Override
    protected Class<? extends ActivityPresenter> onRegisterPresenter() {
        return RegisterPresenter.class;
    }

    @OnClick(R.id.btn_register)
    public void onViewClicked() {
        if (validate())
            getPresenter().onRegister(etEmail.getText().toString().trim(), etPassword.getText().toString().trim());
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

        if (StringUtil.isEmpty(etPasswordConfirm.getText().toString().trim())) {
            showToast(getString(R.string.mess_pass_confirm_empty));
            return false;
        }

        String pass = etPassword.getText().toString().trim();
        String confirmPass = etPasswordConfirm.getText().toString().trim();
        if (!pass.equals(confirmPass)) {
            showToast(getString(R.string.mess_confirm_pass_not_match));
            return false;
        }
        return true;
    }

    @Override
    public void onRegisterSuccess() {
        hideProgressbar();
        Intent intent = new Intent(this, TernRegisterActivity.class);
        intent.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_CLEAR_TASK);
        startActivity(intent);
        finish();
    }

    @Override
    public void onFailed(String message) {
        if (!StringUtil.isEmpty(message)) showToast(message);
    }
}
