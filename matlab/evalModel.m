%AUHTOR: MOHAMMAD MAHDI GHASSEMI, MIT
%EMAIL: ghassemi@mit.edu
function [lse_result] = evalModel(x,y,bval_i,opts,model,i,num_points_to_test,upper_bound,lower_bound,ms)
% Evaluate the passed in function and return the results



%Partition the data into testing and training sets.
Indices = crossvalind('Kfold', size(y,1), 2);       %Generate the indicies

for i=1:2
    testing_ind = Indices == i;                          %testing indicies  (10%)
    training_ind = not(testing_ind);                     %training indicies (90%)
    
    %% CHOOSE THE OPTIMIAL INITIAL STEP UISNG OPTIMIZATION STEP
    problem = createOptimProblem('lsqcurvefit',...
                             'objective', model,...
                             'xdata',x(training_ind,:),...
                             'ydata',y(training_ind),...
                             'x0',ones(1,bval_i),...
                             'lb',lower_bound*ones(1,bval_i),...
                             'ub',upper_bound*ones(1,bval_i));   
    [b,fval,exitflag,output,solutions] = run(ms,problem,num_points_to_test);
    best_coefficients = b;

    %mean squared error for each model
    lse_in(i) = sum((model(best_coefficients,x(testing_ind,:))-y(testing_ind)).^2)/length(y(testing_ind));
    
end
%averaged.
lse_result = mean(lse_in);

end

