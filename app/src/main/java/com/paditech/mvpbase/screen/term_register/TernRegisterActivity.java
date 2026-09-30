package com.paditech.mvpbase.screen.term_register;

import android.content.Intent;
import android.view.View;
import android.widget.Button;
import android.widget.CheckBox;

import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.mvp.activity.ActivityPresenter;
import com.paditech.mvpbase.common.mvp.activity.MVPActivity;
import com.paditech.mvpbase.screen.main.MainActivity;
import com.paditech.mvpbase.screen.update_profile.UpdateProfileActivity;

import butterknife.BindView;
import butterknife.OnClick;

/**
 * Created by Fx570ex on 08-12-2017.
 */

public class TernRegisterActivity extends MVPActivity<TernRegisterContact.PresenterViewOps>
        implements TernRegisterContact.ViewOps {
    @BindView(R.id.btn_confirm)
    Button btnConfirm;
    @BindView(R.id.checkbox)
    CheckBox isPhotoGraph;

    @Override
    protected int getContentView() {

        return R.layout.frag_terms;
    }

    @Override
    protected void initView() {

    }

    @Override
    protected Class<? extends ActivityPresenter> onRegisterPresenter() {
        return TernRegisterPresenter.class;
    }



    @OnClick({R.id.btn_confirm})
    public void onViewClicked(View view) {
        switch (view.getId()) {
            case R.id.btn_confirm:
                if(isPhotoGraph.isChecked() ) {
                    // văng ra màn hình nhập liệu
                    showToast("Bạn là photographer_id");
                    upDateProfile();
                } else  {
                    goToHome();
                }
        }
    }

    public void upDateProfile() {
        hideProgressbar();
        Intent intent = new Intent(this, UpdateProfileActivity.class);
        intent.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_CLEAR_TASK);
        startActivity(intent);
        finish();
    }
    public void goToHome() {
        hideProgressbar();
        Intent intent = new Intent(this, MainActivity.class);
        intent.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_CLEAR_TASK);
        startActivity(intent);
        finish();
    }
}
