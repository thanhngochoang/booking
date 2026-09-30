package com.paditech.mvpbase.common.dialog;

import android.view.View;

import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.base.BaseDialog;

/**
 * Created by ThanhNgocHoang on 5/30/2017.
 */

public class LoadingDialog extends BaseDialog {
    @Override
    protected int getContentView() {
        return R.layout.dialog_loading;
    }

    @Override
    protected void initView(View view) {
        
    }

}
